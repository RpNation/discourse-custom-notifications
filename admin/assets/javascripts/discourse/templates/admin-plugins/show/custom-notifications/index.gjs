import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-config-page__main-area custom-notifications">
    <DPageSubheader
      @titleLabel={{i18n "discourse_custom_notifications.title"}}
      @descriptionLabel={{i18n "discourse_custom_notifications.description"}}
    >
      <:actions as |actions|>
        <actions.Primary
          @route="adminPlugins.show.custom-notifications.new"
          @label="discourse_custom_notifications.new"
          @icon="bullhorn"
        />
      </:actions>
    </DPageSubheader>

    {{#if @model.broadcasts.length}}
      <table class="d-table custom-notifications__history">
        <thead class="d-table__header">
          <tr>
            <th>{{i18n "discourse_custom_notifications.message"}}</th>
            <th>{{i18n "discourse_custom_notifications.status"}}</th>
            <th>{{i18n "discourse_custom_notifications.sent"}}</th>
            <th>{{i18n "discourse_custom_notifications.created"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @model.broadcasts as |broadcast|}}
            <tr class="d-table__row">
              <td class="d-table__cell --overview">
                <LinkTo
                  class="d-table__overview-link custom-notifications__message-link"
                  @route="adminPlugins.show.custom-notifications.show"
                  @model={{broadcast.id}}
                >{{broadcast.message}}</LinkTo>
                <span>{{broadcast.created_by_username}}</span>
              </td>
              <td class="d-table__cell --detail">
                <span class="d-table__mobile-label">{{i18n
                    "discourse_custom_notifications.status"
                  }}</span>
                {{i18n
                  (concat
                    "discourse_custom_notifications.statuses." broadcast.status
                  )
                }}
              </td>
              <td class="d-table__cell --detail">
                <span class="d-table__mobile-label">{{i18n
                    "discourse_custom_notifications.sent"
                  }}</span>
                {{broadcast.sent_count}}
                /
                {{broadcast.total_count}}
              </td>
              <td class="d-table__cell --detail">
                <span class="d-table__mobile-label">{{i18n
                    "discourse_custom_notifications.created"
                  }}</span>
                {{dAgeWithTooltip broadcast.created_at}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
      <p class="custom-notifications__help">{{i18n
          "discourse_custom_notifications.recent_history"
        }}</p>
    {{else}}
      <AdminConfigAreaEmptyList
        @emptyLabel="discourse_custom_notifications.empty"
        @ctaLabel="discourse_custom_notifications.new"
        @ctaRoute="adminPlugins.show.custom-notifications.new"
      />
    {{/if}}
  </div>
</template>
