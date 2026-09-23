import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class CustomNotificationLinkRoute extends DiscourseRoute {
  beforeModel(transition) {
    const { notification_id } = transition.to.params;
    // The server verifies ownership before redirecting to the saved destination.
    DiscourseURL.redirectTo(
      getURL(`/custom-notifications/${encodeURIComponent(notification_id)}`)
    );
  }
}
