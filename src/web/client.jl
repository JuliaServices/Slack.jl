function add_if!(dict::AbstractDict, key::AbstractString, value)
    value === nothing && return dict
    dict[String(key)] = value
    return dict
end

function normalize_attachments(attachments)
    attachments === nothing && return nothing
    return attachments isa AbstractVector ? attachments : [attachments]
end

function chat_post_message(client::WebClient;
    channel::AbstractString,
    text::Union{Nothing, AbstractString}=nothing,
    attachments=nothing,
    thread_ts::Union{Nothing, AbstractString}=nothing,
    reply_broadcast::Union{Nothing, Bool}=nothing,
    unfurl_links::Union{Nothing, Bool}=nothing,
    unfurl_media::Union{Nothing, Bool}=nothing,
    parse::Union{Nothing, AbstractString}=nothing,
    link_names::Union{Nothing, Bool}=nothing,
    mrkdwn::Union{Nothing, Bool}=nothing,
    username::Union{Nothing, AbstractString}=nothing,
    icon_url::Union{Nothing, AbstractString}=nothing,
    icon_emoji::Union{Nothing, AbstractString}=nothing,
)
    payload = Dict{String, Any}("channel" => String(channel))
    add_if!(payload, "text", text)
    add_if!(payload, "thread_ts", thread_ts)
    add_if!(payload, "reply_broadcast", reply_broadcast)
    add_if!(payload, "unfurl_links", unfurl_links)
    add_if!(payload, "unfurl_media", unfurl_media)
    add_if!(payload, "parse", parse)
    add_if!(payload, "link_names", link_names)
    add_if!(payload, "mrkdwn", mrkdwn)
    add_if!(payload, "username", username)
    add_if!(payload, "icon_url", icon_url)
    add_if!(payload, "icon_emoji", icon_emoji)

    normalized_attachments = normalize_attachments(attachments)
    if normalized_attachments !== nothing
        payload["attachments"] = normalized_attachments
    end

    return api_call(client, "chat.postMessage"; json=payload)
end

function chat_update(client::WebClient;
    channel::AbstractString,
    ts::AbstractString,
    text::Union{Nothing, AbstractString}=nothing,
    attachments=nothing,
    parse::Union{Nothing, AbstractString}=nothing,
    link_names::Union{Nothing, Bool}=nothing,
    mrkdwn::Union{Nothing, Bool}=nothing,
)
    payload = Dict{String, Any}(
        "channel" => String(channel),
        "ts" => String(ts),
    )
    add_if!(payload, "text", text)
    add_if!(payload, "parse", parse)
    add_if!(payload, "link_names", link_names)
    add_if!(payload, "mrkdwn", mrkdwn)
    normalized_attachments = normalize_attachments(attachments)
    if normalized_attachments !== nothing
        payload["attachments"] = normalized_attachments
    end

    return api_call(client, "chat.update"; json=payload)
end

function chat_delete(client::WebClient;
    channel::AbstractString,
    ts::AbstractString,
    as_user::Union{Nothing, Bool}=nothing,
)
    payload = Dict{String, Any}(
        "channel" => String(channel),
        "ts" => String(ts),
    )
    add_if!(payload, "as_user", as_user)
    return api_call(client, "chat.delete"; json=payload)
end

function chat_post_ephemeral(client::WebClient;
    channel::AbstractString,
    user::AbstractString,
    text::Union{Nothing, AbstractString}=nothing,
    attachments=nothing,
    thread_ts::Union{Nothing, AbstractString}=nothing,
    parse::Union{Nothing, AbstractString}=nothing,
    link_names::Union{Nothing, Bool}=nothing,
    mrkdwn::Union{Nothing, Bool}=nothing,
)
    payload = Dict{String, Any}(
        "channel" => String(channel),
        "user" => String(user),
    )
    add_if!(payload, "text", text)
    add_if!(payload, "thread_ts", thread_ts)
    add_if!(payload, "parse", parse)
    add_if!(payload, "link_names", link_names)
    add_if!(payload, "mrkdwn", mrkdwn)
    normalized_attachments = normalize_attachments(attachments)
    if normalized_attachments !== nothing
        payload["attachments"] = normalized_attachments
    end

    return api_call(client, "chat.postEphemeral"; json=payload)
end

function conversations_history(client::WebClient;
    channel::AbstractString,
    cursor::Union{Nothing, AbstractString}=nothing,
    limit::Union{Nothing, Integer}=nothing,
    latest::Union{Nothing, AbstractString}=nothing,
    oldest::Union{Nothing, AbstractString}=nothing,
    inclusive::Union{Nothing, Bool}=nothing,
    include_all_metadata::Union{Nothing, Bool}=nothing,
)
    params = Dict{String, Any}(
        "channel" => String(channel),
        "cursor" => cursor,
        "limit" => limit,
        "latest" => latest,
        "oldest" => oldest,
        "inclusive" => inclusive,
        "include_all_metadata" => include_all_metadata,
    )
    return api_call(client, "conversations.history"; http_verb="GET", params=params)
end

function conversations_replies(client::WebClient;
    channel::AbstractString,
    ts::AbstractString,
    cursor::Union{Nothing, AbstractString}=nothing,
    limit::Union{Nothing, Integer}=nothing,
    latest::Union{Nothing, AbstractString}=nothing,
    oldest::Union{Nothing, AbstractString}=nothing,
    inclusive::Union{Nothing, Bool}=nothing,
)
    params = Dict{String, Any}(
        "channel" => String(channel),
        "ts" => String(ts),
        "cursor" => cursor,
        "limit" => limit,
        "latest" => latest,
        "oldest" => oldest,
        "inclusive" => inclusive,
    )
    return api_call(client, "conversations.replies"; http_verb="GET", params=params)
end

function conversations_list(client::WebClient;
    cursor::Union{Nothing, AbstractString}=nothing,
    limit::Union{Nothing, Integer}=nothing,
    types::Union{Nothing, AbstractString, AbstractVector{<:AbstractString}}=nothing,
    exclude_archived::Union{Nothing, Bool}=nothing,
    team_id::Union{Nothing, AbstractString}=nothing,
)
    params = Dict{String, Any}(
        "cursor" => cursor,
        "limit" => limit,
        "types" => types,
        "exclude_archived" => exclude_archived,
        "team_id" => team_id,
    )
    return api_call(client, "conversations.list"; http_verb="GET", params=params)
end

function conversations_info(client::WebClient;
    channel::AbstractString,
    include_locale::Union{Nothing, Bool}=nothing,
    include_num_members::Union{Nothing, Bool}=nothing,
)
    params = Dict{String, Any}(
        "channel" => String(channel),
        "include_locale" => include_locale,
        "include_num_members" => include_num_members,
    )
    return api_call(client, "conversations.info"; http_verb="GET", params=params)
end

function apps_connections_open(client::WebClient;
    app_token::AbstractString,
)
    params = Dict{String, Any}()
    return api_call(client, "apps.connections.open"; http_verb="POST", params=params, token=String(app_token))
end
