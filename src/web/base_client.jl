mutable struct WebClient <: AbstractSlackClient
    token::Union{String, Nothing}
    base_url::String
    timeout::Int
    proxy::Union{String, Nothing}
    headers::Dict{String, String}
    default_params::Dict{String, Any}
    logger::AbstractLogger
end

function WebClient(; token::Union{Nothing, AbstractString}=nothing,
    base_url::AbstractString=DEFAULT_BASE_URL,
    timeout::Integer=30,
    proxy::Union{Nothing, AbstractString}=nothing,
    headers=nothing,
    user_agent_prefix::Union{Nothing, AbstractString}=nothing,
    user_agent_suffix::Union{Nothing, AbstractString}=nothing,
    team_id::Union{Nothing, AbstractString}=nothing,
    logger::Union{Nothing, AbstractLogger}=nothing)

    token_value = token === nothing ? nothing : strip(String(token))
    base_url_value = normalize_base_url(base_url)

    header_dict = Dict{String, String}()
    if headers !== nothing
        for (k, v) in headers
            header_dict[string(k)] = string(v)
        end
    end

    if !haskey(header_dict, "User-Agent")
        header_dict["User-Agent"] = get_user_agent(user_agent_prefix, user_agent_suffix)
    end

    default_params = Dict{String, Any}()
    if team_id !== nothing
        default_params["team_id"] = team_id
    end

    proxy_value = proxy === nothing || isempty(strip(String(proxy))) ? load_http_proxy_from_env() : String(proxy)
    logger_value = logger === nothing ? Logging.global_logger() : logger

    return WebClient(token_value, base_url_value, Int(timeout), proxy_value, header_dict, default_params, logger_value)
end

function build_auth_header(auth)
    if auth isa AbstractString
        return String(auth)
    elseif auth isa AbstractDict
        client_id = get(() -> nothing, auth, "client_id")
        client_secret = get(() -> nothing, auth, "client_secret")
        if client_id === nothing || client_secret === nothing
            throw(ArgumentError("auth dict must include client_id and client_secret"))
        end
        encoded = base64encode(codeunits("$(client_id):$(client_secret)"))
        return "Basic $(encoded)"
    elseif auth isa NamedTuple
        return build_auth_header(to_dict(auth))
    end
    throw(ArgumentError("Unsupported auth type: $(typeof(auth))"))
end

function build_headers(client::WebClient; headers=nothing, token_override=nothing, has_json=false, has_files=false, auth=nothing)
    final_headers = Dict{String, String}()
    if !has_files
        if has_json
            final_headers["Content-Type"] = "application/json;charset=utf-8"
        else
            final_headers["Content-Type"] = "application/x-www-form-urlencoded"
        end
    end

    token_value = token_override === nothing ? client.token : token_override
    if token_value !== nothing
        final_headers["Authorization"] = "Bearer $(token_value)"
    end

    for (k, v) in client.headers
        final_headers[k] = v
    end

    if headers !== nothing
        for (k, v) in headers
            final_headers[string(k)] = string(v)
        end
    end

    if has_files
        if haskey(final_headers, "Content-Type")
            delete!(final_headers, "Content-Type")
        end
        if haskey(final_headers, "content-type")
            delete!(final_headers, "content-type")
        end
    end

    if auth !== nothing
        final_headers["Authorization"] = build_auth_header(auth)
    end

    return final_headers
end

function build_req_args(client::WebClient; http_verb::AbstractString, files=nothing, data=nothing, params=nothing, json=nothing, headers=nothing, auth=nothing, token=nothing)
    if json !== nothing && uppercase(String(http_verb)) != "POST"
        msg = "Json data can only be submitted as POST requests. GET requests should use the params argument."
        throw(SlackRequestError(msg))
    end

    data_dict = data === nothing ? nothing : remove_nothing_values(to_dict(data))
    params_dict = params === nothing ? nothing : remove_nothing_values(to_dict(params))
    json_dict = json === nothing ? nothing : to_dict(json)

    if data_dict !== nothing
        apply_default_params!(data_dict, client.default_params)
        data_dict = convert_bool_to_0_or_1(data_dict)
    end
    if params_dict !== nothing
        apply_default_params!(params_dict, client.default_params)
        params_dict = convert_bool_to_0_or_1(params_dict)
    end
    if json_dict !== nothing
        apply_default_params!(json_dict, client.default_params)
    end

    token_override = token === nothing ? nothing : String(token)
    if params_dict !== nothing && haskey(params_dict, "token")
        token_override = String(params_dict["token"])
        delete!(params_dict, "token")
    end
    if json_dict !== nothing && haskey(json_dict, "token")
        token_override = String(json_dict["token"])
        delete!(json_dict, "token")
    end

    final_headers = build_headers(client; headers=headers, token_override=token_override, has_json=json_dict !== nothing, has_files=files !== nothing, auth=auth)

    return Dict{String, Any}(
        "http_verb" => uppercase(String(http_verb)),
        "headers" => final_headers,
        "data" => data_dict,
        "params" => params_dict,
        "json" => json_dict,
        "files" => files,
        "auth" => auth,
    )
end

function api_call(client::WebClient, api_method::AbstractString;
    http_verb::AbstractString="POST",
    files=nothing,
    data=nothing,
    params=nothing,
    json=nothing,
    headers=nothing,
    auth=nothing,
    token=nothing)

    api_url = get_url(client.base_url, api_method)
    req_args = build_req_args(client; http_verb=http_verb, files=files, data=data, params=params, json=json, headers=headers, auth=auth, token=token)
    return send_request(client, api_url, req_args)
end

function request_for_pagination(client::WebClient, api_url::AbstractString, req_args::Dict{String, Any})
    return send_request(client, String(api_url), req_args)
end

function should_parse_json(headers::Dict{String, String}, body::AbstractVector{UInt8})
    content_type = lowercase(get(() -> get(() -> "", headers, "content-type"), headers, "Content-Type"))
    if occursin("json", content_type)
        return true
    end
    if isempty(body)
        return false
    end
    for byte in body
        if byte == UInt8('\n') || byte == UInt8('\r') || byte == UInt8(' ') || byte == UInt8('\t')
            continue
        end
        return byte == UInt8('{') || byte == UInt8('[')
    end
    return false
end

function parse_response_body(headers::Dict{String, String}, body::AbstractVector{UInt8})
    if should_parse_json(headers, body)
        try
            return JSON.parse(body, JSON.Object)
        catch err
            message = "Unexpected response body: $(String(body))"
            return JSON.Object("ok" => false, "error" => message)
        end
    end
    return body
end

function build_form_body(data::AbstractDict, files)
    form_fields = Pair{String, Any}[]
    for (k, v) in data
        push!(form_fields, string(k) => normalize_param_value(v))
    end

    opened_files = IO[]
    if files !== nothing
        for (k, v) in files
            if v isa AbstractString
                io = open(v, "r")
                push!(opened_files, io)
                push!(form_fields, string(k) => HTTP.Multipart(basename(v), io))
            elseif v isa IO
                push!(form_fields, string(k) => HTTP.Multipart("file", v))
            elseif v isa AbstractVector{UInt8}
                io = IOBuffer(v)
                push!(form_fields, string(k) => HTTP.Multipart("file", io))
            else
                push!(form_fields, string(k) => v)
            end
        end
    end

    return HTTP.Form(form_fields), opened_files
end

function send_request(client::WebClient, api_url::AbstractString, req_args::Dict{String, Any})
    http_verb = get(() -> "POST", req_args, "http_verb")
    headers = get(() -> Dict{String, String}(), req_args, "headers")
    params = get(() -> Dict{String, Any}(), req_args, "params")
    data = get(() -> Dict{String, Any}(), req_args, "data")
    json_body = get(() -> nothing, req_args, "json")
    files = get(() -> nothing, req_args, "files")

    request_body = HTTP.nobody
    query_params = nothing
    opened_files = IO[]

    if files !== nothing
        merged = Dict{String, Any}()
        if params !== nothing
            for (k, v) in params
                merged[k] = v
            end
        end
        if data !== nothing
            for (k, v) in data
                merged[k] = v
            end
        end
        request_body, opened_files = build_form_body(merged, files)
    elseif json_body !== nothing
        request_body = JSON.json(json_body)
    elseif http_verb == "GET"
        query_params = params === nothing ? Dict{String, String}() : normalize_query_params(params)
    else
        merged = Dict{String, Any}()
        if params !== nothing
            for (k, v) in params
                merged[k] = v
            end
        end
        if data !== nothing
            for (k, v) in data
                merged[k] = v
            end
        end
        request_body = isempty(merged) ? HTTP.nobody : form_encode(merged)
    end

    response = HTTP.request(http_verb, api_url;
        headers=headers,
        body=request_body,
        query=query_params,
        connect_timeout=client.timeout,
        readtimeout=client.timeout,
        proxy=client.proxy,
    )

    response_headers = Dict{String, String}()
    for (k, v) in response.headers
        response_headers[k] = v
    end

    data_value = parse_response_body(response_headers, response.body)
    resp = SlackResponse(
        client,
        http_verb,
        String(api_url),
        req_args,
        data_value,
        response_headers,
        Int(response.status),
    )

    for io in opened_files
        try
            close(io)
        catch
        end
    end

    return validate(resp)
end
