json.id resource.id
json.avatar_url resource.try(:avatar_url)
json.channel_id resource.channel_id
json.name resource.name
json.channel_type resource.channel_type
json.warn_on_existing_conversation resource.warn_on_existing_conversation
json.provider resource.channel.try(:provider)
