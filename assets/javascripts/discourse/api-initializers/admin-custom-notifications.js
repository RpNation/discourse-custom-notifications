import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  if (!api.getCurrentUser()?.admin) {
    return;
  }

  api.addAdminPluginConfigurationNav("discourse-custom-notifications", [
    {
      label: "discourse_custom_notifications.title",
      route: "adminPlugins.show.custom-notifications",
      description: "discourse_custom_notifications.description",
    },
  ]);
});
