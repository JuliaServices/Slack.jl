struct WebhookResponse
    url::String
    status_code::Int
    body::String
    headers::Dict{String, String}
end

function Base.show(io::IO, resp::WebhookResponse)
    print(io, "WebhookResponse(status=$(resp.status_code), body=$(resp.body))")
end

function is_ok(resp::WebhookResponse)
    return resp.status_code == 200 && strip(resp.body) == "ok"
end
