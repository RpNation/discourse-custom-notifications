import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import MultiSelect from "discourse/select-kit/components/multi-select";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CustomNotificationComposer extends Component {
  @service router;

  @tracked draft;
  @tracked preview;
  @tracked sending = false;

  #payload;
  #requestId;

  constructor() {
    super(...arguments);
    this.draft = {
      sender_username: this.args.currentUsername,
      message: "",
      link_url: "",
      link_title: "",
      username: "",
      username_exact: false,
      email: "",
      email_exact: false,
      primary_group_id: "",
      include_group_ids: [],
      exclude_group_ids: [],
    };
  }

  @action
  async previewNotification(data) {
    const { message, sender_username, link_url, link_title, ...filters } = data;
    const payload = { message, sender_username, link_url, link_title, filters };
    try {
      const response = await ajax("/admin/custom-notifications/preview.json", {
        type: "POST",
        data: payload,
      });
      this.draft = data;
      this.#payload = payload;
      this.#requestId = crypto.randomUUID();
      this.preview = response;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  editNotification() {
    this.preview = null;
  }

  @action
  async sendNotification() {
    if (this.sending || !this.preview?.recipient_count) {
      return;
    }
    this.sending = true;
    try {
      const response = await ajax("/admin/custom-notifications.json", {
        type: "POST",
        data: {
          ...this.#payload,
          preview_token: this.preview.preview_token,
          request_id: this.#requestId,
        },
      });
      this.router.transitionTo(
        "adminPlugins.show.custom-notifications.show",
        response.broadcast.id
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.sending = false;
    }
  }

  <template>
    <div class="custom-notifications" ...attributes>
      <BackButton
        @route="adminPlugins.show.custom-notifications"
        @label="discourse_custom_notifications.back"
      />
      <h2>{{i18n "discourse_custom_notifications.new"}}</h2>

      {{#if this.preview}}
        <AdminConfigAreaCard @heading="discourse_custom_notifications.preview">
          <:content>
            <div class="custom-notifications__preview">
              {{dIcon "bullhorn"}}
              <div>
                <strong>{{this.preview.preview.sender_username}}</strong>
                <p
                  class="custom-notifications__body"
                >{{this.preview.preview.message}}</p>
                {{#if this.preview.preview.link_url}}
                  <p><strong>{{this.preview.preview.link_title}}</strong></p>
                  <code
                    class="custom-notifications__url"
                  >{{this.preview.preview.link_url}}</code>
                {{/if}}
              </div>
            </div>
            <p class="custom-notifications__audience-count" role="status">
              {{i18n
                "discourse_custom_notifications.recipient_count"
                count=this.preview.recipient_count
              }}
            </p>
            {{#if this.preview.sample_users.length}}
              <p>{{i18n "discourse_custom_notifications.sample"}}</p>
              <ul class="custom-notifications__samples">
                {{#each this.preview.sample_users as |user|}}
                  <li>{{user.username}}</li>
                {{/each}}
              </ul>
            {{/if}}
            <p class="custom-notifications__help">{{i18n
                "discourse_custom_notifications.confirm_help"
              }}</p>
            <div class="custom-notifications__actions">
              <DButton
                class="btn-primary"
                @action={{this.sendNotification}}
                @label="discourse_custom_notifications.send"
                @icon="bullhorn"
                @disabled={{unless
                  this.preview.recipient_count
                  true
                  this.sending
                }}
                @isLoading={{this.sending}}
              />
              <DButton
                class="btn-default"
                @action={{this.editNotification}}
                @disabled={{this.sending}}
                @label="discourse_custom_notifications.edit"
              />
            </div>
          </:content>
        </AdminConfigAreaCard>
      {{else}}
        <AdminConfigAreaCard>
          <:content>
            <Form
              class="custom-notifications__form"
              @data={{this.draft}}
              @onSubmit={{this.previewNotification}}
              as |form|
            >
              <form.Section
                @title={{i18n "discourse_custom_notifications.content"}}
              >
                <form.Field
                  @format="full"
                  @name="sender_username"
                  @title={{i18n "discourse_custom_notifications.sender"}}
                  @description={{i18n
                    "discourse_custom_notifications.sender_help"
                  }}
                  @type="input"
                  as |field|
                ><field.Control /></form.Field>
                <form.Field
                  @format="full"
                  @name="message"
                  @title={{i18n "discourse_custom_notifications.message"}}
                  @description={{i18n
                    "discourse_custom_notifications.message_help"
                  }}
                  @type="textarea"
                  @validation="required|length:1,500"
                  as |field|
                ><field.Control rows="4" /></form.Field>
                <form.Field
                  @format="full"
                  @name="link_url"
                  @title={{i18n "discourse_custom_notifications.link_url"}}
                  @description={{i18n
                    "discourse_custom_notifications.link_help"
                  }}
                  @type="input"
                  as |field|
                ><field.Control /></form.Field>
                <form.Field
                  @format="full"
                  @name="link_title"
                  @title={{i18n "discourse_custom_notifications.link_title"}}
                  @type="input"
                  @validation="length:0,100"
                  as |field|
                ><field.Control /></form.Field>
              </form.Section>
              <form.Section
                @title={{i18n "discourse_custom_notifications.recipients"}}
              >
                <p class="custom-notifications__help">{{i18n
                    "discourse_custom_notifications.filters_help"
                  }}</p>
                <form.Field
                  @format="full"
                  @name="username"
                  @title={{i18n "discourse_custom_notifications.username"}}
                  @type="input"
                  as |field|
                >
                  <field.Control />
                </form.Field>
                <form.Field
                  @format="full"
                  @name="username_exact"
                  @title={{i18n
                    "discourse_custom_notifications.username_exact"
                  }}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </form.Field>
                <form.Field
                  @format="full"
                  @name="email"
                  @title={{i18n "discourse_custom_notifications.email"}}
                  @type="input"
                  as |field|
                >
                  <field.Control />
                </form.Field>
                <form.Field
                  @format="full"
                  @name="email_exact"
                  @title={{i18n "discourse_custom_notifications.email_exact"}}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </form.Field>
                <form.Field
                  @format="full"
                  @name="primary_group_id"
                  @title={{i18n "discourse_custom_notifications.primary_group"}}
                  @type="select"
                  as |field|
                >
                  <field.Control
                    @nonePlaceholder={{i18n
                      "discourse_custom_notifications.any_group"
                    }}
                    as |select|
                  >
                    {{#each @groups as |group|}}
                      <select.Option
                        @value={{group.id}}
                      >{{group.name}}</select.Option>
                    {{/each}}
                  </field.Control>
                </form.Field>
                <form.Field
                  @format="full"
                  @name="include_group_ids"
                  @title={{i18n
                    "discourse_custom_notifications.include_groups"
                  }}
                  @description={{i18n
                    "discourse_custom_notifications.include_groups_help"
                  }}
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <MultiSelect
                      @id={{field.id}}
                      @content={{@groups}}
                      @value={{field.value}}
                      @onChange={{field.set}}
                    />
                  </field.Control>
                </form.Field>
                <form.Field
                  @format="full"
                  @name="exclude_group_ids"
                  @title={{i18n
                    "discourse_custom_notifications.exclude_groups"
                  }}
                  @description={{i18n
                    "discourse_custom_notifications.exclude_groups_help"
                  }}
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <MultiSelect
                      @id={{field.id}}
                      @content={{@groups}}
                      @value={{field.value}}
                      @onChange={{field.set}}
                    />
                  </field.Control>
                </form.Field>
              </form.Section>
              <form.Actions>
                <form.Submit @label="discourse_custom_notifications.preview" />
              </form.Actions>
            </Form>
          </:content>
        </AdminConfigAreaCard>
      {{/if}}
    </div>
  </template>
}
