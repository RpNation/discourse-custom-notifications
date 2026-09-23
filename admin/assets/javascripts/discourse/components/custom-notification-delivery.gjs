import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class CustomNotificationDelivery extends Component {
  @tracked broadcast;
  @tracked busy = false;
  @tracked refreshFailed = false;
  #timer;

  constructor() {
    super(...arguments);
    this.broadcast = this.args.broadcast;
    this.#scheduleRefresh();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#timer);
  }

  get finished() {
    return this.broadcast.status === "completed";
  }

  get processedCount() {
    return this.broadcast.sent_count + this.broadcast.skipped_count;
  }

  @action
  async refresh() {
    cancel(this.#timer);
    try {
      const response = await ajax(
        `/admin/custom-notifications/${this.broadcast.id}.json`
      );
      if (!this.isDestroying && !this.isDestroyed) {
        this.broadcast = response.broadcast;
        this.refreshFailed = false;
      }
    } catch {
      if (!this.isDestroying && !this.isDestroyed) {
        this.refreshFailed = true;
      }
    } finally {
      this.#scheduleRefresh();
    }
  }

  @action
  async retry() {
    this.busy = true;
    try {
      const response = await ajax(
        `/admin/custom-notifications/${this.broadcast.id}/retry.json`,
        { type: "POST" }
      );
      this.broadcast = response.broadcast;
      this.#scheduleRefresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  #scheduleRefresh() {
    cancel(this.#timer);
    if (!this.finished && !this.isDestroying && !this.isDestroyed) {
      this.#timer = later(this, this.refresh, 4000);
    }
  }

  <template>
    <div class="custom-notifications" ...attributes>
      <BackButton
        @route="adminPlugins.show.custom-notifications"
        @label="discourse_custom_notifications.back"
      />
      <h2>{{i18n "discourse_custom_notifications.delivery"}}</h2>
      <AdminConfigAreaCard @heading="discourse_custom_notifications.progress">
        <:content>
          <p class="custom-notifications__status" role="status">
            {{i18n
              (concat
                "discourse_custom_notifications.statuses." this.broadcast.status
              )
            }}
          </p>
          <progress
            class="custom-notifications__progress"
            aria-label={{i18n "discourse_custom_notifications.progress"}}
            value={{this.processedCount}}
            max={{this.broadcast.total_count}}
          ></progress>
          <p>{{i18n
              "discourse_custom_notifications.progress_counts"
              sent=this.broadcast.sent_count
              skipped=this.broadcast.skipped_count
              total=this.broadcast.total_count
            }}</p>
          <p class="custom-notifications__help">{{i18n
              "discourse_custom_notifications.progress_help"
            }}</p>
          {{#if this.broadcast.last_error}}
            <p
              class="alert alert-error"
              role="alert"
            >{{this.broadcast.last_error}}</p>
          {{/if}}
          {{#if this.refreshFailed}}
            <p class="alert alert-error" role="alert">{{i18n
                "discourse_custom_notifications.refresh_failed"
              }}</p>
          {{/if}}
          <div class="custom-notifications__actions">
            <DButton
              class="btn-default"
              @action={{this.refresh}}
              @label="discourse_custom_notifications.refresh"
              @icon="rotate"
            />
            {{#unless this.finished}}
              <DButton
                class="btn-primary"
                @action={{this.retry}}
                @label="discourse_custom_notifications.retry"
                @isLoading={{this.busy}}
                @disabled={{this.busy}}
              />
            {{/unless}}
          </div>
        </:content>
      </AdminConfigAreaCard>
      <AdminConfigAreaCard @heading="discourse_custom_notifications.content">
        <:content>
          <p><strong>{{this.broadcast.sender_username}}</strong></p>
          <p class="custom-notifications__body">{{this.broadcast.message}}</p>
          {{#if this.broadcast.link_url}}
            <p>{{this.broadcast.link_title}}</p>
            <code
              class="custom-notifications__url"
            >{{this.broadcast.link_url}}</code>
          {{/if}}
          <p class="custom-notifications__help">{{i18n
              "discourse_custom_notifications.created_by"
              username=this.broadcast.created_by_username
            }}</p>
        </:content>
      </AdminConfigAreaCard>
    </div>
  </template>
}
