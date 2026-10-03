# The public base of the absolute links gameble hands out (CAP-9): a shared
# card's link, its og:url and its canonical link. It comes from PUBLIC_URL
# (AD-21: configuration from the environment only), without a trailing
# slash, and never from the request's Host header, which a client can forge.
# Unset outside production, PublicUrlsHelper falls back to the request's
# base; in production an unset PUBLIC_URL is an error where it is needed.
Rails.application.config.x.public_url = ENV["PUBLIC_URL"].presence&.chomp("/")
