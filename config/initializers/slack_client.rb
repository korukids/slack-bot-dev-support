$slack_client = Slack::Web::Client.new(token: ENV.fetch('SLACK_API_TOKEN', nil))
