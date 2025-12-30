# Slack Event Types for direct JSON parsing

# Base event fields shared by all event types
@omit_null @kwarg struct SlackAppMentionEvent
    type::Union{String, Nothing} = nothing
    channel::Union{String, Nothing} = nothing
    user::Union{String, Nothing} = nothing
    text::Union{String, Nothing} = nothing
    ts::Union{String, Nothing} = nothing
    thread_ts::Union{String, Nothing} = nothing
    event_ts::Union{String, Nothing} = nothing
end

@omit_null @kwarg struct SlackMessageEvent
    type::Union{String, Nothing} = nothing
    subtype::Union{String, Nothing} = nothing
    channel::Union{String, Nothing} = nothing
    channel_type::Union{String, Nothing} = nothing
    user::Union{String, Nothing} = nothing
    bot_id::Union{String, Nothing} = nothing
    text::Union{String, Nothing} = nothing
    ts::Union{String, Nothing} = nothing
    thread_ts::Union{String, Nothing} = nothing
    event_ts::Union{String, Nothing} = nothing
end

const SlackEventPayload = Union{SlackAppMentionEvent, SlackMessageEvent, JSON.Object}

JSON.@choosetype SlackEventPayload x -> begin
    event_type = x.type[]
    if event_type == "app_mention"
        return SlackAppMentionEvent
    elseif event_type == "message"
        return SlackMessageEvent
    end
    return JSON.Object
end

# Envelope for events_api payloads
@omit_null @kwarg struct SlackEventsApiPayload
    type::Union{String, Nothing} = nothing
    team_id::Union{String, Nothing} = nothing
    event::Union{SlackEventPayload, Nothing} = nothing
    event_id::Union{String, Nothing} = nothing
    event_time::Union{Int, Nothing} = nothing
end
