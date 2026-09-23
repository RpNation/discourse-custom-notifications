import NotificationDelivery from "discourse/plugins/discourse-custom-notifications/discourse/components/custom-notification-delivery";

export default <template>
  <NotificationDelivery @broadcast={{@model}} />
</template>
