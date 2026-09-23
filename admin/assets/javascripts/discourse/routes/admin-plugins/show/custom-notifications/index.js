import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class CustomNotificationsIndexRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/custom-notifications.json");
  }

  titleToken() {
    return i18n("discourse_custom_notifications.title");
  }
}
