using Test
using Slack
using JSON
using Logging

@testset "Models" begin
    attachment = Attachment(text="hello", markdown_in=["text"])
    encoded = JSON.json(attachment)
    decoded = JSON.parse(encoded, JSON.Object)
    @test decoded["text"] == "hello"
    @test decoded["mrkdwn_in"] == ["text"]
end

@testset "Webhooks" begin
    response = WebhookResponse("https://hooks.slack.com/test", 200, "ok", Dict())
    @test Slack.is_ok(response)
end

@testset "Socket Mode" begin
    raw = "{\"type\":\"events_api\",\"envelope_id\":\"123\",\"payload\":{}}"
    request = JSON.parse(raw, SocketModeRequest)
    @test request.envelope_id == "123"
end

getenv_str(name) = (value = strip(get(() -> "", ENV, name)); isempty(value) ? nothing : value)

function wait_for(predicate; timeout=10.0, interval=0.1)
    deadline = time() + timeout
    while time() < deadline
        predicate() && return true
        sleep(interval)
    end
    return false
end

function take_with_timeout(ch::Channel; timeout=10.0, interval=0.1)
    deadline = time() + timeout
    while time() < deadline
        isready(ch) && return take!(ch)
        sleep(interval)
    end
    return nothing
end

@testset "Web API Integration" begin
    token = getenv_str("SLACK_BOT_TOKEN")
    channel = getenv_str("SLACK_TEST_CHANNEL")
    if token === nothing || channel === nothing
        @info "Skipping Web API integration tests (set SLACK_BOT_TOKEN and SLACK_TEST_CHANNEL)."
        return
    end

    client = WebClient(token=token)
    base_text = "slack-julia-sdk test $(time_ns())"
    attachment = Attachment(text="attachment $(time_ns())", color="#439FE0")

    parent_ts = nothing
    reply_ts = nothing

    try
        response = Slack.chat_post_message(client; channel=channel, text=base_text, attachments=[attachment])
        @test Slack.is_ok(response)
        message = response["message"]
        @test message isa AbstractDict
        parent_ts = get(() -> nothing, message, "ts")
        @test parent_ts isa AbstractString

        updated_text = base_text * " updated"
        updated = Slack.chat_update(client; channel=channel, ts=parent_ts, text=updated_text)
        @test updated["message"]["text"] == updated_text

        reply_text = base_text * " reply"
        reply = Slack.chat_post_message(client; channel=channel, text=reply_text, thread_ts=parent_ts)
        reply_message = reply["message"]
        reply_ts = get(() -> nothing, reply_message, "ts")
        @test reply_ts isa AbstractString

        replies = Slack.conversations_replies(client; channel=channel, ts=parent_ts, limit=10)
        messages = replies["messages"]
        @test messages isa AbstractVector
        @test any(msg -> get(() -> "", msg, "ts") == reply_ts, messages)

        history = Slack.conversations_history(client; channel=channel, limit=5)
        @test history["messages"] isa AbstractVector

        info = Slack.conversations_info(client; channel=channel)
        @test info["channel"]["id"] == channel
    finally
        if reply_ts !== nothing
            Slack.chat_delete(client; channel=channel, ts=reply_ts)
        end
        if parent_ts !== nothing
            Slack.chat_delete(client; channel=channel, ts=parent_ts)
        end
    end
end

@testset "Stream Mode Integration" begin
    token = getenv_str("SLACK_BOT_TOKEN")
    channel = getenv_str("SLACK_TEST_CHANNEL")
    recipient_team_id = getenv_str("SLACK_STREAM_RECIPIENT_TEAM_ID")
    recipient_user_id = getenv_str("SLACK_STREAM_RECIPIENT_USER_ID")
    if token === nothing || channel === nothing || recipient_team_id === nothing || recipient_user_id === nothing
        @info "Skipping Stream Mode integration tests (set SLACK_BOT_TOKEN, SLACK_TEST_CHANNEL, SLACK_STREAM_RECIPIENT_TEAM_ID, SLACK_STREAM_RECIPIENT_USER_ID)."
        return
    end

    client = WebClient(token=token)
    parent_ts = nothing
    stream_ts = nothing
    try
        parent = Slack.chat_post_message(client; channel=channel, text="stream parent $(time_ns())")
        parent_ts = get(() -> nothing, parent, "ts")
        if parent_ts === nothing
            message = parent["message"]
            parent_ts = get(() -> nothing, message, "ts")
        end
        @test parent_ts isa AbstractString

        stream = Slack.chat_stream(
            client;
            channel=channel,
            thread_ts=parent_ts,
            recipient_team_id=recipient_team_id,
            recipient_user_id=recipient_user_id,
            buffer_size=8,
        )
        @test Slack.append!(stream; markdown_text="Hello ") === nothing
        response = Slack.append!(stream; markdown_text="world")
        @test response isa SlackResponse
        stop_response = Slack.stop!(stream; markdown_text="!")
        @test Slack.is_ok(stop_response)
        stream_ts = stream.stream_ts
    finally
        if stream_ts !== nothing
            Slack.chat_delete(client; channel=channel, ts=stream_ts)
        end
        if parent_ts !== nothing
            Slack.chat_delete(client; channel=channel, ts=parent_ts)
        end
    end
end

@testset "Webhook Integration" begin
    url = getenv_str("SLACK_WEBHOOK_URL")
    if url === nothing
        @info "Skipping Webhook integration tests (set SLACK_WEBHOOK_URL)."
        return
    end

    client = WebhookClient(url)
    text = "slack-julia-sdk webhook test $(time_ns())"
    response = Slack.send(client; text=text)
    @test Slack.is_ok(response)
end

@testset "Socket Mode Integration" begin
    app_token = getenv_str("SLACK_APP_TOKEN")
    if app_token === nothing
        @info "Skipping Socket Mode integration tests (set SLACK_APP_TOKEN)."
        return
    end

    bot_token = getenv_str("SLACK_BOT_TOKEN")
    channel = getenv_str("SLACK_TEST_CHANNEL")
    event_flag = getenv_str("SLACK_SOCKET_MODE_EVENT_TEST")
    run_event_test = event_flag === nothing ? true : !(lowercase(event_flag) in ("0", "false", "no"))

    web_client = bot_token === nothing ? WebClient() : WebClient(token=bot_token)
    socket_client = SocketModeClient(app_token; web_client=web_client, auto_reconnect=false)

    request_channel = nothing
    if run_event_test && bot_token !== nothing && channel !== nothing
        request_channel = Channel{SocketModeRequest}(1)
        request_listener = function (_, request)
            request.envelope_id === nothing && return
            put!(request_channel, request)
        end
        Slack.add_request_listener!(socket_client, request_listener)
    end

    task = Slack.start!(socket_client)
    connected = wait_for(() -> Slack.is_connected(socket_client); timeout=10.0)
    @test connected

    if request_channel !== nothing
        Slack.chat_post_message(web_client; channel=channel, text="socket mode test $(time_ns())")
        request = take_with_timeout(request_channel; timeout=15.0)
        @test request !== nothing
        if request !== nothing
            response = Slack.ack!(socket_client, request)
            @test response.envelope_id == request.envelope_id
        end
    else
        @info "Skipping Socket Mode event tests (set SLACK_BOT_TOKEN and SLACK_TEST_CHANNEL, or set SLACK_SOCKET_MODE_EVENT_TEST=0 to disable)."
    end

    Slack.close!(socket_client)
    @test wait_for(() -> !Slack.is_connected(socket_client); timeout=5.0)
end
