require 'spec_helper'
require 'date'

describe 'SlackDevSupport support reminder builders' do
  let(:posted) { [] }

  around do |example|
    original = $slack_client
    fake = Object.new
    captured = posted
    fake.define_singleton_method(:chat_postMessage) { |args| captured << args }
    $slack_client = fake
    example.run
    $slack_client = original
  end

  before do
    # Seed an on-support dev as the rotation tail.
    UserRegister.add(user: 'U_DEV', channel: $channel)
  end

  def yesterday_ts
    (Time.now.to_i - (24 * 60 * 60)).to_s
  end

  def today_ts
    Time.now.to_i.to_s
  end

  describe '.assign carryover' do
    it 'posts only the assignment message when nothing is carrying over' do
      SlackDevSupport.assign
      expect(posted.length).to eq(1)
      expect(posted.first[:text]).to include('on dev support today')
      expect(posted.first[:text]).not_to include('Still open from previous days')
    end

    it 'does not treat today\'s requests as carryover' do
      SupportRequest.create_request(ts: today_ts, user: 'U_OP', text: 'today', channel: $channel)
      SlackDevSupport.assign
      expect(posted.first[:text]).not_to include('Still open from previous days')
    end

    it 'appends prior-day open requests to the assignment message' do
      SupportRequest.create_request(ts: yesterday_ts, user: 'U_OP', text: 'old', channel: $channel)
      SlackDevSupport.assign
      expect(posted.length).to eq(1)
      expect(posted.first[:text]).to include('on dev support today')
      expect(posted.first[:text]).to include('Still open from previous days')
    end
  end

  describe '.post_nudge' do
    it 'stays silent when nothing is open' do
      SlackDevSupport.post_nudge
      expect(posted).to be_empty
    end

    # A second request the same day (a distinct ts on today's date).
    def another_today_ts
      "#{today_ts}.000200"
    end

    it 'reminds the on-support dev with open/closed counts' do
      SupportRequest.create_request(ts: today_ts, user: 'U_OP', text: 'now', channel: $channel)
      SupportRequest.create_request(ts: another_today_ts, user: 'U_OP', text: 'done', channel: $channel)
      SupportRequest.mark_closed(ts: another_today_ts, at: Time.now.to_i)

      SlackDevSupport.post_nudge
      expect(posted.length).to eq(1)
      expect(posted.first[:text]).to start_with('Mid-day nudge (<@U_DEV>): 1 open, 1 closed')
    end

    it 'lists only the still-open requests, not closed ones' do
      SupportRequest.create_request(ts: today_ts, user: 'U_OP', text: 'still open', channel: $channel)
      SupportRequest.create_request(ts: another_today_ts, user: 'U_OP', text: 'all done', channel: $channel)
      SupportRequest.mark_closed(ts: another_today_ts, at: Time.now.to_i)

      SlackDevSupport.post_nudge
      body = posted.first[:text]
      expect(body).to include('still open')
      expect(body).not_to include('all done')
    end
  end

  describe '.post_end_of_day_summary' do
    it 'always posts, with an all-clear note when empty' do
      SlackDevSupport.post_end_of_day_summary
      expect(posted.length).to eq(1)
      expect(posted.first[:text]).to include('All clear')
    end

    it 'reports the day’s counts on a single stats line' do
      SupportRequest.create_request(ts: today_ts, user: 'U_OP', text: 'now', channel: $channel)
      SlackDevSupport.post_end_of_day_summary
      expect(posted.length).to eq(1)
      expect(posted.first[:text])
        .to include('Dev-support wrap-up for today: 1 request, 0 closed, 1 carrying into tomorrow')
      expect(posted.first[:text]).to include('Still open')
    end

    it 'does not expose request state words in the lines' do
      SupportRequest.create_request(ts: today_ts, user: 'U_OP', text: 'now', channel: $channel)
      SupportRequest.mark_investigating(ts: today_ts, at: Time.now.to_i)
      SlackDevSupport.post_end_of_day_summary
      body = posted.first[:text]
      %w[investigating acknowledged new].each { |state| expect(body).not_to include(state) }
    end
  end

  describe 'request line rendering' do
    it 'links the request via a snippet label, not a bare URL, and suppresses unfurling' do
      text = 'Prod deploy is failing on the migration step and blocking the release tonight'
      SupportRequest.create_request(ts: today_ts, user: 'U_OP', text:, channel: $channel)
      SlackDevSupport.post_nudge

      body = posted.first[:text]
      # Slack hyperlink form <url|label> with a truncated, quoted snippet.
      expect(body).to match(%r{<https://slack\.com/archives/\S+\|“Prod deploy is failing[^”]*…”>})
      # The raw URL is never shown outside the link target.
      expect(body).not_to match(/\shttps:\/\/slack\.com\/archives/)
      expect(posted.first[:unfurl_links]).to be(false)
      expect(posted.first[:unfurl_media]).to be(false)
    end

    it 'falls back to a generic label when the request has no text' do
      SupportRequest.create_request(ts: today_ts, user: 'U_OP', text: '', channel: $channel)
      SlackDevSupport.post_nudge
      expect(posted.first[:text]).to include('|view request>')
    end
  end
end
