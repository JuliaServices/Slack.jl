abstract type SlackError <: Exception end
abstract type SlackClientError <: SlackError end

struct SlackRequestError <: SlackClientError
    message::String
end

struct SlackApiError <: SlackClientError
    message::String
    response::Any
end

struct SlackTokenRotationError <: SlackClientError
    api_error::SlackApiError
end

struct SlackClientNotConnectedError <: SlackClientError
    message::String
end

struct SlackObjectFormationError <: SlackClientError
    message::String
end

struct SlackClientConfigurationError <: SlackClientError
    message::String
end

struct BotUserAccessError <: SlackClientError
    message::String
end

SlackRequestError(msg::AbstractString) = SlackRequestError(String(msg))
SlackClientNotConnectedError(msg::AbstractString) = SlackClientNotConnectedError(String(msg))
SlackObjectFormationError(msg::AbstractString) = SlackObjectFormationError(String(msg))
SlackClientConfigurationError(msg::AbstractString) = SlackClientConfigurationError(String(msg))
BotUserAccessError(msg::AbstractString) = BotUserAccessError(String(msg))

function Base.showerror(io::IO, err::SlackRequestError)
    print(io, err.message)
end

function Base.showerror(io::IO, err::SlackApiError)
    print(io, err.message)
    print(io, "\nThe server responded with: ")
    print(io, err.response)
end

function Base.showerror(io::IO, err::SlackTokenRotationError)
    print(io, "Slack token rotation failed: ")
    showerror(io, err.api_error)
end

function Base.showerror(io::IO, err::SlackClientNotConnectedError)
    print(io, err.message)
end

function Base.showerror(io::IO, err::SlackObjectFormationError)
    print(io, err.message)
end

function Base.showerror(io::IO, err::SlackClientConfigurationError)
    print(io, err.message)
end

function Base.showerror(io::IO, err::BotUserAccessError)
    print(io, err.message)
end
