# Custom notifications for Discourse

An admin tool for sending targeted notices through Discourse's notification menu.

## Use

Enable `discourse_custom_notifications_enabled`, then open **Admin → Plugins → Custom notifications → Custom notifications**.

1. Choose an existing sender username, or leave it blank to use `system`.
2. Enter a plain-text message and optional link/title.
3. Filter by username, email, primary group, included groups, or excluded groups.
4. Preview the matching count, sample recipients, and message.
5. Confirm the send. The delivery page shows progress and lets you resume unfinished deliveries.

The admin route is `/admin/plugins/discourse-custom-notifications/notifications`.
Messages support 500 characters, titles 100, and URLs 2,048. The final encoded notification must also fit Discourse's 1,000-character data limit; the form reports an error if escaping pushes it over that limit. HTML, Markdown, BBCode, and placeholders are displayed literally.

## Recipient matching

- Blank filters match all eligible members. All populated filters combine.
- Username and email matching are case-insensitive; select exact matching when needed. Email filtering checks all saved addresses, without exposing addresses to recipients.
- Included groups match membership in any selected group; excluded groups take precedence.
- Primary group is a separate filter. Implicit groups such as everyone, anonymous users, and logged-in users are omitted; leave the inclusion filter blank for all eligible members.
- Inactive, unapproved, staged, suspended, system, and anonymous accounts are excluded. Expired suspensions are eligible again.
- Preview counts reflect membership at preview time. The recipient list is saved when sending; later group changes do not alter it. Deleted or newly ineligible accounts are skipped at delivery time.

## Background delivery

Each confirmed send creates a broadcast and a recipient ledger using one database `INSERT ... SELECT`, without loading the whole audience into Ruby. Sidekiq then processes **100 recipients per job** and queues the next batch.

The notification, delivery status, and counts are committed in the same row-locked transaction. Duplicate jobs and retries skip delivered rows, including when core has since purged the notification. A unique request ID also prevents a retried HTTP request from creating the same broadcast twice.

Disabling the plugin pauses unfinished delivery. Re-enable it and use **Resume unfinished delivery** to continue. Sidekiq retries unexpected failures; delivery history records the last error. If queueing is interrupted after a send is saved, the same resume action schedules it again.

This sends in-site notifications only, without email or desktop push. Native unread counts and notification-created events still run; configured notification webhooks may receive the recipient-visible notification data.

## Permissions and rendering

All management endpoints and service operations require an administrator. Signed previews are bound to the administrator and exact content/filters and expire after 15 minutes. The initiating admin is recorded separately from the displayed sender, with an entry in Discourse's staff action log.

Messages remain escaped text. Links accept site-relative paths or HTTP(S) URLs; script URLs, protocol-relative URLs, control characters, and embedded credentials are rejected. Notification links go through an authenticated endpoint that verifies the notification belongs to the current user before redirecting. Recipient filters and email addresses are never included in notification payloads.

The renderer extends Discourse's existing custom notification renderer only for this plugin's marker. Other plugins' custom notifications retain their normal rendering.

## Development

Generated from the [official Discourse plugin skeleton](https://github.com/discourse/discourse-plugin-skeleton). Uses native admin plugin routes, FormKit, translated strings, Discourse service contracts, generated migrations, Sidekiq, and the plugin notification renderer API. No core patches or additional runtime gems are required.

Install the complete directory as `plugins/discourse-custom-notifications`, run plugin migrations, and restart Rails, Sidekiq, and the frontend development server as applicable. Requires current Discourse with the modern admin plugin interface and UI kit.

```sh
LOAD_PLUGINS=1 bin/rspec plugins/discourse-custom-notifications/spec
bin/qunit --standalone --target discourse-custom-notifications
bin/lint --fix plugins/discourse-custom-notifications/path/to/changed-file
```

Backend coverage includes authorization, filter validation, signed previews, owned redirects, recipient snapshots, bounded batches, rollback, eligibility changes, and retry deduplication. Frontend coverage includes native notification escaping/fallback and the preview/confirmation/edit workflow.

Validated locally on Discourse `c9d27d5d2e`: 27 backend examples, nine QUnit tests, and Discourse lint pass. A real admin-only local demonstration also verified preview, confirmation, Sidekiq delivery, progress updates, direct page reload, native notification history, and clicking through to the saved destination. Desktop and 390-pixel mobile previews had no horizontal overflow or browser errors.

Delivery history retains the latest 50 sends in the admin list; older records and delivery ledgers remain stored to preserve deduplication and notification links. This version has no history purge, scheduling, email delivery, rich text, or cancellation UI.
