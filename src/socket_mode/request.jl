@omit_null @kwarg struct SocketModeRequest
    type::Union{String, Nothing} = nothing
    envelope_id::Union{String, Nothing} = nothing
    payload::Union{JSON.Object, Nothing} = nothing
    accepts_response_payload::Union{Bool, Nothing} = nothing
    retry_attempt::Union{Int, Nothing} = nothing
    retry_reason::Union{String, Nothing} = nothing
end

function parse_socket_mode_request(raw::AbstractString)
    return JSON.parse(raw, SocketModeRequest)
end
