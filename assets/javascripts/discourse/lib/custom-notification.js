import getURL from "discourse/lib/get-url";
import CustomNotification from "discourse/lib/notification-types/custom";
import { i18n } from "discourse-i18n";

export default class extends CustomNotification {
  get description() {
    return this.#isBroadcast
      ? this.notification.data.topic_title
      : super.description;
  }

  get icon() {
    return this.#isBroadcast ? "bullhorn" : super.icon;
  }

  get linkHref() {
    if (!this.#isBroadcast) {
      return super.linkHref;
    }

    if (this.notification.data.has_link === true) {
      return getURL(`/custom-notifications/${this.notification.id}`);
    }
  }

  get linkTitle() {
    if (!this.#isBroadcast) {
      return super.linkTitle;
    }

    return (
      this.notification.data.link_title ||
      i18n("discourse_custom_notifications.notification_title")
    );
  }

  get #isBroadcast() {
    return (
      this.notification.data.message === "discourse_custom_notifications.notice"
    );
  }
}
