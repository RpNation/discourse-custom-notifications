import NotificationComposer from "discourse/plugins/discourse-custom-notifications/discourse/components/custom-notification-composer";

export default <template>
  <NotificationComposer
    @groups={{@model.groups}}
    @currentUsername={{@model.current_username}}
  />
</template>
