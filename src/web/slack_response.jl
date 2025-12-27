mutable struct SlackResponse
    client::AbstractSlackClient
    http_verb::String
    api_url::String
    req_args::Dict{String, Any}
    data::Any
    headers::Dict{String, String}
    status_code::Int
end

function Base.show(io::IO, resp::SlackResponse)
    if resp.data isa AbstractDict
        print(io, resp.data)
    elseif resp.data isa AbstractVector{UInt8}
        print(io, "<binary data>")
    else
        print(io, resp.data)
    end
end

function Base.getindex(resp::SlackResponse, key::AbstractString)
    data = resp.data
    data isa AbstractDict || throw(ArgumentError("Response data is not a dictionary"))
    return get(() -> nothing, data, key)
end

Base.getindex(resp::SlackResponse, key::Symbol) = resp[string(key)]

function Base.haskey(resp::SlackResponse, key::AbstractString)
    data = resp.data
    data isa AbstractDict || return false
    return haskey(data, key)
end

Base.haskey(resp::SlackResponse, key::Symbol) = haskey(resp, string(key))

function Base.get(resp::SlackResponse, key::AbstractString, default=nothing)
    data = resp.data
    data isa AbstractDict || return default
    return get(() -> default, data, key)
end

function Base.get(resp::SlackResponse, key::Symbol, default=nothing)
    data = resp.data
    data isa AbstractDict || return default
    return get(() -> default, data, string(key))
end

function Base.get(f::Function, resp::SlackResponse, key::AbstractString)
    data = resp.data
    data isa AbstractDict || return f()
    return get(f, data, key)
end

function Base.get(f::Function, resp::SlackResponse, key::Symbol)
    data = resp.data
    data isa AbstractDict || return f()
    return get(f, data, string(key))
end

function is_ok(resp::SlackResponse)
    data = resp.data
    data isa AbstractDict || return false
    return get(() -> false, data, "ok") == true
end

function next_cursor(data)
    data isa AbstractDict || return nothing
    response_metadata = get(() -> nothing, data, "response_metadata")
    cursor = nothing
    if response_metadata isa AbstractDict
        cursor = get(() -> nothing, response_metadata, "next_cursor")
    end
    if cursor === nothing
        cursor = get(() -> nothing, data, "next_cursor")
    end
    if cursor isa AbstractString && !isempty(cursor)
        return cursor
    end
    return nothing
end

function validate(resp::SlackResponse)
    if resp.status_code == 200
        if resp.data isa AbstractVector{UInt8}
            return resp
        end
        if resp.data isa AbstractDict && get(() -> false, resp.data, "ok") == true
            return resp
        end
    end
    msg = "The request to the Slack API failed. (url: $(resp.api_url))"
    throw(SlackApiError(msg, resp))
end

function Base.iterate(resp::SlackResponse, state=0)
    if state == 0
        return resp, 1
    end
    cursor = next_cursor(resp.data)
    cursor === nothing && return nothing

    req_args = copy(resp.req_args)
    params = get(() -> Dict{String, Any}(), req_args, "params")
    params = params === nothing ? Dict{String, Any}() : copy(params)
    params["cursor"] = cursor
    req_args["params"] = params

    next_resp = request_for_pagination(resp.client, resp.api_url, req_args)
    return next_resp, state + 1
end
