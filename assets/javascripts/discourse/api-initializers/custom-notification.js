import { apiInitializer } from "discourse/lib/api";
import CustomNotification from "discourse/plugins/discourse-custom-notifications/discourse/lib/custom-notification";

export default apiInitializer((api) => {
  if (
    !api.container.lookup("service:site-settings")
      .discourse_custom_notifications_enabled
  ) {
    return;
  }

  api.registerNotificationTypeRenderer("custom", () => CustomNotification);
});
