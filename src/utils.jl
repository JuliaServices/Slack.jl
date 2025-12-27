const DEFAULT_BASE_URL = "https://slack.com/api/"

abstract type AbstractSlackClient end

normalize_base_url(base_url::AbstractString) = endswith(base_url, "/") ? String(base_url) : String(base_url) * "/"

function get_url(base_url::AbstractString, api_method::AbstractString)
    method = startswith(api_method, "/") ? api_method[2:end] : api_method
    return normalize_base_url(base_url) * method
end

function get_user_agent(prefix::Union{Nothing, AbstractString}=nothing, suffix::Union{Nothing, AbstractString}=nothing)
    base = "Julia/$(VERSION) slackclient/$(SDK_VERSION) $(Sys.KERNEL)/$(Sys.MACHINE)"
    prefix_val = prefix === nothing ? "" : String(prefix) * " "
    suffix_val = suffix === nothing ? "" : " " * String(suffix)
    return prefix_val * base * suffix_val
end

function load_http_proxy_from_env()
    for key in ("HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy")
        value = strip(get(() -> "", ENV, key))
        if !isempty(value)
            return value
        end
    end
    return nothing
end

function to_dict(input)
    input === nothing && return nothing
    if input isa JSON.Object
        return JSON.Object(input)
    elseif input isa AbstractDict
        output = JSON.Object{String, Any}()
        for (k, v) in input
            output[string(k)] = v
        end
        return output
    elseif input isa NamedTuple
        output = JSON.Object{String, Any}()
        for k in keys(input)
            output[string(k)] = getfield(input, k)
        end
        return output
    else
        throw(ArgumentError("Expected a dict-like value, got $(typeof(input))"))
    end
end

function remove_nothing_values(input::AbstractDict)
    output = JSON.Object()
    for (k, v) in input
        if v === nothing || v === missing
            continue
        end
        output[string(k)] = v
    end
    return output
end

function apply_default_params!(target::AbstractDict, defaults::AbstractDict)
    for (k, v) in defaults
        if !haskey(target, k)
            target[k] = v
        end
    end
    return target
end

function convert_bool_to_0_or_1(input::AbstractDict)
    output = JSON.Object()
    for (k, v) in input
        if v isa Bool
            output[string(k)] = v ? "1" : "0"
        else
            output[string(k)] = v
        end
    end
    return output
end

function normalize_param_value(value)
    if value isa Bool
        return value ? "1" : "0"
    elseif value isa AbstractVector
        if all(x -> x isa AbstractString || x isa Number || x isa Bool, value)
            return join(string.(value), ",")
        end
        return JSON.json(value)
    elseif value isa AbstractDict
        return JSON.json(value)
    elseif StructUtils.structlike(StructUtils.DefaultStyle(), value)
        return JSON.json(value)
    else
        return string(value)
    end
end

function normalize_query_params(params::AbstractDict)
    output = Dict{String, String}()
    for (k, v) in params
        if v === nothing || v === missing
            continue
        end
        output[string(k)] = normalize_param_value(v)
    end
    return output
end

function form_encode(params::AbstractDict)
    parts = String[]
    for (k, v) in params
        if v === nothing || v === missing
            continue
        end
        key = HTTP.URIs.escapeuri(string(k))
        value = HTTP.URIs.escapeuri(normalize_param_value(v))
        push!(parts, key * "=" * value)
    end
    return join(parts, "&")
end
