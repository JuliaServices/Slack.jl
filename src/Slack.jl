module Slack

using Base64
using HTTP
using JSON
using Logging
using StructUtils

const SDK_VERSION = v"0.1.0"

include("errors.jl")
include("utils.jl")

include("models/attachments.jl")
include("models/messages.jl")

include("web/slack_response.jl")
include("web/base_client.jl")
include("web/client.jl")
include("web/chat_stream.jl")

include("webhook/webhook_response.jl")
include("webhook/client.jl")

include("socket_mode/request.jl")
include("socket_mode/response.jl")
include("socket_mode/client.jl")

export SDK_VERSION
export WebClient, WebhookClient, SocketModeClient
export ChatStream
export SlackResponse, WebhookResponse
export SocketModeRequest, SocketModeResponse
export Attachment, AttachmentField, Message, ThreadReply, Conversation
export SlackClientError, SlackRequestError, SlackApiError, SlackTokenRotationError
export SlackClientNotConnectedError, SlackObjectFormationError, SlackClientConfigurationError
export BotUserAccessError

end # module Slack
