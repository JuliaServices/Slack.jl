mutable struct SocketModeClient
    app_token::String
    web_client::WebClient
    logger::AbstractLogger
    wss_url::Union{String, Nothing}
    ws::Union{HTTP.WebSockets.WebSocket, Nothing}
    closed::Bool
    auto_reconnect::Bool
    message_listeners::Vector{Function}
    request_listeners::Vector{Function}
    send_lock::ReentrantLock
    connect_lock::ReentrantLock
    runner::Union{Task, Nothing}
end

function SocketModeClient(app_token::AbstractString;
    web_client::Union{Nothing, WebClient}=nothing,
    logger::Union{Nothing, AbstractLogger}=nothing,
    auto_reconnect::Bool=true)

    client = web_client === nothing ? WebClient() : web_client
    logger_value = logger === nothing ? Logging.global_logger() : logger

    return SocketModeClient(
        String(app_token),
        client,
        logger_value,
        nothing,
        nothing,
        false,
        auto_reconnect,
        Function[],
        Function[],
        ReentrantLock(),
        ReentrantLock(),
        nothing,
    )
end

function is_connected(client::SocketModeClient)
    ws = client.ws
    return ws !== nothing && !HTTP.WebSockets.isclosed(ws) && !client.closed
end

function add_message_listener!(client::SocketModeClient, listener::Function)
    push!(client.message_listeners, listener)
    return client
end

function add_request_listener!(client::SocketModeClient, listener::Function)
    push!(client.request_listeners, listener)
    return client
end

function issue_new_wss_url(client::SocketModeClient; max_retries::Int=5)
    attempts = 0
    while true
        try
            response = apps_connections_open(client.web_client; app_token=client.app_token)
            return response["url"]
        catch err
            if err isa SlackApiError
                data = err.response.data
                error_code = data isa AbstractDict ? get(() -> nothing, data, "error") : nothing
                if error_code == "ratelimited" && attempts < max_retries
                    headers = err.response.headers
                    retry_value = get(() -> get(() -> "30", headers, "retry-after"), headers, "Retry-After")
                    retry_after = something(tryparse(Int, retry_value), 30)
                    sleep(retry_after)
                    attempts += 1
                    continue
                end
            end
            rethrow()
        end
    end
end

function send_message(client::SocketModeClient, message::AbstractString)
    if !is_connected(client)
        throw(SlackClientNotConnectedError("Socket Mode client is not connected"))
    end
    lock(client.send_lock)
    try
        HTTP.WebSockets.send(client.ws, String(message))
    finally
        unlock(client.send_lock)
    end
end

function send_socket_mode_response(client::SocketModeClient, response)
    if response isa SocketModeResponse
        send_message(client, JSON.json(response))
    elseif response isa AbstractDict
        send_message(client, JSON.json(response))
    else
        send_message(client, String(response))
    end
end

function ack!(client::SocketModeClient, request::SocketModeRequest; payload=nothing)
    response = SocketModeResponse(envelope_id=request.envelope_id, payload=payload)
    send_socket_mode_response(client, response)
    return response
end

function handle_socket_message(client::SocketModeClient, raw_message::AbstractString)
    message = nothing
    try
        message = JSON.parse(raw_message, JSON.Object)
    catch
        return
    end

    if get(() -> nothing, message, "type") == "disconnect"
        if client.auto_reconnect
            Threads.@spawn reconnect!(client)
        end
        return
    end

    for listener in client.message_listeners
        try
            listener(client, message, raw_message)
        catch err
            @error "Failed to run a message listener" exception=(err, catch_backtrace())
        end
    end

    if !isempty(client.request_listeners)
        request = nothing
        try
            request = parse_socket_mode_request(raw_message)
        catch err
            @error "Failed to parse Socket Mode request" exception=(err, catch_backtrace())
        end
        if request !== nothing
            for listener in client.request_listeners
                try
                    listener(client, request)
                catch err
                    @error "Failed to run a request listener" exception=(err, catch_backtrace())
                end
            end
        end
    end
end

function run_socket_mode(client::SocketModeClient)
    lock(client.connect_lock)
    try
        client.wss_url = issue_new_wss_url(client)
        client.closed = false
    finally
        unlock(client.connect_lock)
    end

    HTTP.WebSockets.open(client.wss_url; proxy=client.web_client.proxy) do ws
        client.ws = ws
        for msg in ws
            raw_message = msg isa AbstractVector{UInt8} ? String(msg) : String(msg)
            handle_socket_message(client, raw_message)
            if client.closed
                break
            end
        end
    end

    client.ws = nothing
    return nothing
end

function run!(client::SocketModeClient)
    return run_socket_mode(client)
end

function start!(client::SocketModeClient)
    client.runner = Threads.@spawn run_socket_mode(client)
    return client.runner
end

function connect!(client::SocketModeClient)
    return start!(client)
end

function reconnect!(client::SocketModeClient)
    disconnect!(client)
    return start!(client)
end

function disconnect!(client::SocketModeClient)
    client.closed = true
    if client.ws !== nothing
        try
            HTTP.WebSockets.close(client.ws)
        catch
        end
    end
    client.ws = nothing
    return client
end

function close!(client::SocketModeClient)
    return disconnect!(client)
end

function SocketModeClient(f::Function, app_token::AbstractString; kwargs...)
    client = SocketModeClient(app_token; kwargs...)
    try
        f(client)
    finally
        close!(client)
    end
    return nothing
end

"""
    run!(f, app_token; kwargs...)

Run a socket mode client with `f` as the request handler.

This is a convenience method that creates a client, adds `f` as a request listener,
runs the client (blocking), and closes it when done.

# Example
```julia
Slack.run!(app_token; web_client=web_client) do client, request
    Slack.ack!(client, request)
    # handle request.payload
end
```
"""
function run!(f::Function, app_token::AbstractString; kwargs...)
    SocketModeClient(app_token; kwargs...) do client
        add_request_listener!(client, f)
        run!(client)
    end
end
