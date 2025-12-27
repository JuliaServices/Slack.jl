@omit_null @kwarg struct AttachmentField
    title::Union{String, Nothing} = nothing
    value::Union{String, Nothing} = nothing
    short::Bool = true
end

@omit_null @kwarg struct Attachment
    text::Union{String, Nothing} = nothing
    fallback::Union{String, Nothing} = nothing
    fields::Vector{AttachmentField} = AttachmentField[]
    color::Union{String, Nothing} = nothing
    markdown_in::Vector{String} = String[] &(json=(name="mrkdwn_in",),)
    title::Union{String, Nothing} = nothing
    title_link::Union{String, Nothing} = nothing
    pretext::Union{String, Nothing} = nothing
    author_name::Union{String, Nothing} = nothing
    author_subname::Union{String, Nothing} = nothing
    author_link::Union{String, Nothing} = nothing
    author_icon::Union{String, Nothing} = nothing
    image_url::Union{String, Nothing} = nothing
    thumb_url::Union{String, Nothing} = nothing
    footer::Union{String, Nothing} = nothing
    footer_icon::Union{String, Nothing} = nothing
    ts::Union{Int, Nothing} = nothing
end
