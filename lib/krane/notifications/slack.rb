# Copyright 2020 Appvia Ltd <info@appvia.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Understands how to deliver Slack notifications for the Rbacvis report items

require 'slack-notifier'
require 'singleton'

module Krane
  module Notifications
    class Slack
      include Singleton
      include Helpers

      def initialize
        config = load_config_yaml 'config.yaml'

        @webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', config[:config][:notifications][:slack].try(:[], :webhook_url))
        @channel     = ENV.fetch('SLACK_CHANNEL', config[:config][:notifications][:slack].try(:[], :channel))

        unless [ @webhook_url, @channel ].all?(&:present?)
          say 'Slack notifications disabled due to missing webhook_url or channel. These can be set in config/config.yaml or via SLACK_WEBHOOK_URL & SLACK_CHANNEL environment variables'.yellow
          return
        end

        @client = ::Slack::Notifier.new @webhook_url do
          defaults username: 'rbacvis'
        end
      end

      def publish cluster, report
        return if report.blank?
        return unless @client

        report.each do |item|
          status = item[:status]
          next if [:success, :info].include?(status)
          title  = "<#{cluster}> [#{status}] #{item[:group_title]}"
          text   = [item[:info], "\n"]
          unless item[:items].blank?
            item[:items].each do |i|
              text << "- #{i}"
            end
          end

          say "Slack - Notification to channel: #{@channel}, Title: #{title}"

          @client.post(
            attachments: [slack_attachment(status, title, text.join("\n"))],
            channel: @channel,
            icon_emoji: slack_icon(status)
          )
        end

      end

      private

      def slack_attachment status, title, text
        {
          fallback: slack_fallback_text(status, title, text),
          color: slack_color(status),
          title: ::Slack::Notifier::Util::LinkFormatter.format(title),
          text: ::Slack::Notifier::Util::LinkFormatter.format(text),
        }
      end

      def slack_fallback_text status, title, text
        m = []
        m << title
        m << text
        m.join(' - ');
      end

      def slack_color status
        [:success, :info].include?(status) ? 'good' : status.to_s
      end

      def slack_icon status
        [:danger, :warning].include?(status) ? ':warning:' : ':raised_hands:'
      end

    end
  end
end
