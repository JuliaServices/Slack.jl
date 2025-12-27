mutable struct ChatStream
    client::WebClient
    logger::AbstractLogger
    channel::String
    thread_ts::String
    recipient_team_id::Union{String, Nothing}
    recipient_user_id::Union{String, Nothing}
    start_args::NamedTuple
    buffer::String
    state::String
    stream_ts::Union{String, Nothing}
    buffer_size::Int
    token::Union{String, Nothing}
end

function ChatStream(client::WebClient;
    channel::AbstractString,
    thread_ts::AbstractString,
    buffer_size::Integer=256,
    recipient_team_id::Union{Nothing, AbstractString}=nothing,
    recipient_user_id::Union{Nothing, AbstractString}=nothing,
    token::Union{Nothing, AbstractString}=nothing,
    logger::Union{Nothing, AbstractLogger}=nothing,
    kwargs...)

    logger_value = logger === nothing ? client.logger : logger
    start_args = (; kwargs...)

    token_value = token === nothing ? nothing : String(token)

    return ChatStream(
        client,
        logger_value,
        String(channel),
        String(thread_ts),
        recipient_team_id === nothing ? nothing : String(recipient_team_id),
        recipient_user_id === nothing ? nothing : String(recipient_user_id),
        start_args,
        "",
        "starting",
        nothing,
        Int(buffer_size),
        token_value,
    )
end

function append!(stream::ChatStream; markdown_text::AbstractString, token=nothing, kwargs...)
    if stream.state == "completed"
        throw(SlackRequestError("Cannot append to stream: stream state is $(stream.state)"))
    end

    if token !== nothing
        stream.token = String(token)
    end

    stream.buffer *= String(markdown_text)
    if ncodeunits(stream.buffer) >= stream.buffer_size
        return flush_buffer!(stream; kwargs...)
    end

    details = JSON.json(Dict(
        "buffer_length" => ncodeunits(stream.buffer),
        "buffer_size" => stream.buffer_size,
        "channel" => stream.channel,
        "recipient_team_id" => stream.recipient_team_id,
        "recipient_user_id" => stream.recipient_user_id,
        "thread_ts" => stream.thread_ts,
    ))
    @debug "ChatStream appended to buffer" details
    return nothing
end

function stop!(stream::ChatStream;
    markdown_text::Union{Nothing, AbstractString}=nothing,
    blocks=nothing,
    metadata=nothing,
    token=nothing,
    kwargs...)

    if stream.state == "completed"
        throw(SlackRequestError("Cannot stop stream: stream state is $(stream.state)"))
    end

    if token !== nothing
        stream.token = String(token)
    end

    if markdown_text !== nothing
        stream.buffer *= String(markdown_text)
    end

    if stream.stream_ts === nothing
        start_kwargs = stream.start_args
        response = chat_start_stream(
            stream.client;
            channel=stream.channel,
            thread_ts=stream.thread_ts,
            recipient_team_id=stream.recipient_team_id,
            recipient_user_id=stream.recipient_user_id,
            markdown_text=stream.buffer,
            token=stream.token,
            start_kwargs...,
        )
        ts = get(() -> nothing, response, "ts")
        ts === nothing && throw(SlackRequestError("Failed to stop stream: stream not started"))
        stream.stream_ts = String(ts)
        stream.state = "in_progress"
    end

    response = chat_stop_stream(
        stream.client;
        channel=stream.channel,
        ts=stream.stream_ts,
        markdown_text=stream.buffer,
        blocks=blocks,
        metadata=metadata,
        token=stream.token,
        kwargs...,
    )

    stream.state = "completed"
    stream.buffer = ""
    return response
end

function flush_buffer!(stream::ChatStream; token=nothing, kwargs...)
    if token !== nothing
        stream.token = String(token)
    end

    if stream.stream_ts === nothing
        start_kwargs = merge(stream.start_args, (; kwargs...))
        response = chat_start_stream(
            stream.client;
            channel=stream.channel,
            thread_ts=stream.thread_ts,
            recipient_team_id=stream.recipient_team_id,
            recipient_user_id=stream.recipient_user_id,
            markdown_text=stream.buffer,
            token=stream.token,
            start_kwargs...,
        )
        ts = get(() -> nothing, response, "ts")
        ts !== nothing && (stream.stream_ts = String(ts))
        stream.state = "in_progress"
    else
        response = chat_append_stream(
            stream.client;
            channel=stream.channel,
            ts=stream.stream_ts,
            markdown_text=stream.buffer,
            token=stream.token,
            kwargs...,
        )
    end

    stream.buffer = ""
    return response
end
