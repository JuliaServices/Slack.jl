mutable struct WebhookClient
    url::String
    timeout::Int
    proxy::Union{String, Nothing}
    default_headers::Dict{String, String}
    logger::AbstractLogger
    max_retries::Int
end

function WebhookClient(url::AbstractString;
    timeout::Integer=30,
    proxy::Union{Nothing, AbstractString}=nothing,
    default_headers=nothing,
    user_agent_prefix::Union{Nothing, AbstractString}=nothing,
    user_agent_suffix::Union{Nothing, AbstractString}=nothing,
    logger::Union{Nothing, AbstractLogger}=nothing,
    max_retries::Integer=0)

    headers_dict = Dict{String, String}()
    if default_headers !== nothing
        for (k, v) in default_headers
            headers_dict[string(k)] = string(v)
        end
    end
    if !haskey(headers_dict, "User-Agent")
        headers_dict["User-Agent"] = get_user_agent(user_agent_prefix, user_agent_suffix)
    end

    proxy_value = proxy === nothing || isempty(strip(String(proxy))) ? load_http_proxy_from_env() : String(proxy)
    logger_value = logger === nothing ? Logging.global_logger() : logger

    return WebhookClient(String(url), Int(timeout), proxy_value, headers_dict, logger_value, Int(max_retries))
end

function send(client::WebhookClient;
    text::Union{Nothing, AbstractString}=nothing,
    attachments=nothing,
    response_type::Union{Nothing, AbstractString}=nothing,
    replace_original::Union{Nothing, Bool}=nothing,
    delete_original::Union{Nothing, Bool}=nothing,
    unfurl_links::Union{Nothing, Bool}=nothing,
    unfurl_media::Union{Nothing, Bool}=nothing,
    metadata=nothing,
    headers=nothing,
)
    body = Dict{String, Any}()
    add_if!(body, "text", text)
    add_if!(body, "response_type", response_type)
    add_if!(body, "replace_original", replace_original)
    add_if!(body, "delete_original", delete_original)
    add_if!(body, "unfurl_links", unfurl_links)
    add_if!(body, "unfurl_media", unfurl_media)
    normalized_attachments = normalize_attachments(attachments)
    if normalized_attachments !== nothing
        body["attachments"] = normalized_attachments
    end
    if metadata !== nothing
        body["metadata"] = metadata
    end
    return send_dict(client, body; headers=headers)
end

function send_dict(client::WebhookClient, body::AbstractDict; headers=nothing)
    payload = JSON.json(remove_nothing_values(body))

    request_headers = Dict{String, String}()
    for (k, v) in client.default_headers
        request_headers[k] = v
    end
    request_headers["Content-Type"] = "application/json;charset=utf-8"
    if headers !== nothing
        for (k, v) in headers
            request_headers[string(k)] = string(v)
        end
    end

    attempts = 0
    while true
        response = HTTP.request("POST", client.url;
            headers=request_headers,
            body=payload,
            connect_timeout=client.timeout,
            readtimeout=client.timeout,
            proxy=client.proxy,
        )

        response_headers = Dict{String, String}()
        for (k, v) in response.headers
            response_headers[k] = v
        end

        body_text = String(response.body)
        resp = WebhookResponse(client.url, Int(response.status), body_text, response_headers)
        if response.status == 429 && attempts < client.max_retries
            retry_value = get(() -> get(() -> "30", response_headers, "retry-after"), response_headers, "Retry-After")
            retry_after = something(tryparse(Int, retry_value), 30)
            sleep(retry_after)
            attempts += 1
            continue
        end
        if response.status >= 500 && attempts < client.max_retries
            sleep(min(2 ^ attempts, 30))
            attempts += 1
            continue
        end
        return resp
    end
end
