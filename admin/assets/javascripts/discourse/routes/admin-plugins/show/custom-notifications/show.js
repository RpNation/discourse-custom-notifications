import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class CustomNotificationsShowRoute extends DiscourseRoute {
  async model({ broadcast_id }) {
    const response = await ajax(
      `/admin/custom-notifications/${broadcast_id}.json`
    );
    return response.broadcast;
  }

  titleToken() {
    return i18n("discourse_custom_notifications.delivery");
  }
}
