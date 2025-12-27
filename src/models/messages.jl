@omit_null @kwarg struct ThreadReply
    user::Union{String, Nothing} = nothing
    ts::Union{String, Nothing} = nothing
end

@omit_null @kwarg struct Message
    type::Union{String, Nothing} = nothing
    subtype::Union{String, Nothing} = nothing
    user::Union{String, Nothing} = nothing
    text::Union{String, Nothing} = nothing
    ts::Union{String, Nothing} = nothing
    thread_ts::Union{String, Nothing} = nothing
    reply_count::Union{Int, Nothing} = nothing
    reply_users::Vector{String} = String[]
    replies::Vector{ThreadReply} = ThreadReply[]
    latest_reply::Union{String, Nothing} = nothing
    attachments::Vector{Attachment} = Attachment[]
end

@omit_null @kwarg struct Conversation
    id::Union{String, Nothing} = nothing
    name::Union{String, Nothing} = nothing
    is_channel::Union{Bool, Nothing} = nothing
    is_group::Union{Bool, Nothing} = nothing
    is_im::Union{Bool, Nothing} = nothing
    is_private::Union{Bool, Nothing} = nothing
    is_archived::Union{Bool, Nothing} = nothing
    is_general::Union{Bool, Nothing} = nothing
    is_shared::Union{Bool, Nothing} = nothing
    is_org_shared::Union{Bool, Nothing} = nothing
    is_member::Union{Bool, Nothing} = nothing
    num_members::Union{Int, Nothing} = nothing
    topic::Union{JSON.Object, Nothing} = nothing
    purpose::Union{JSON.Object, Nothing} = nothing
end
