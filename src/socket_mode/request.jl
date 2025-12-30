const SocketModePayload = Union{SlackEventsApiPayload, JSON.Object}

JSON.@choosetype SocketModePayload x -> begin
    obj = x[]
    obj isa AbstractDict || return JSON.Object
    event_value = get(() -> nothing, obj, "event")
    event_value === nothing ? JSON.Object : SlackEventsApiPayload
end

@omit_null @kwarg struct SocketModeRequest
    type::Union{String, Nothing} = nothing
    envelope_id::Union{String, Nothing} = nothing
    payload::Union{SocketModePayload, Nothing} = nothing
    accepts_response_payload::Union{Bool, Nothing} = nothing
    retry_attempt::Union{Int, Nothing} = nothing
    retry_reason::Union{String, Nothing} = nothing
end

function parse_socket_mode_request(raw::AbstractString)
    return JSON.parse(raw, SocketModeRequest)
end

function parse_socket_mode_request(raw::AbstractVector{UInt8})
    return JSON.parse(raw, SocketModeRequest)
end
