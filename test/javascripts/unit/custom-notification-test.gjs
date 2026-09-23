import { isHTMLSafe } from "@ember/template";
import { render } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import MenuItem from "discourse/components/user-menu/menu-item";
import getURL from "discourse/lib/get-url";
import NativeCustomNotification from "discourse/lib/notification-types/custom";
import { withPluginApi } from "discourse/lib/plugin-api";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import CustomNotification from "discourse/plugins/discourse-custom-notifications/discourse/lib/custom-notification";

function buildNotification(data = {}) {
  return Notification.create({
    id: 42,
    user_id: 1,
    notification_type: NOTIFICATION_TYPES.custom,
    read: false,
    high_priority: false,
    data: {
      message: "discourse_custom_notifications.notice",
      topic_title: "The community event starts tomorrow.",
      display_username: "admin",
      custom_notifications_id: 12,
      has_link: true,
      link_title: "Read the announcement",
      ...data,
    },
  });
}

module("Unit | Lib | custom-notification", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.options = {
      site: this.owner.lookup("service:site"),
      siteSettings: this.owner.lookup("service:site-settings"),
    };
  });

  test("renders a broadcast using its plain body and authenticated link", function (assert) {
    const notification = buildNotification();
    const director = new CustomNotification({ ...this.options, notification });

    assert.strictEqual(
      director.description,
      notification.data.topic_title,
      "the body is displayed directly"
    );
    assert.strictEqual(
      director.icon,
      "bullhorn",
      "broadcasts use the notice icon"
    );
    assert.strictEqual(director.label, "admin", "the actual sender is shown");
    assert.strictEqual(
      director.linkHref,
      getURL("/custom-notifications/42"),
      "navigation goes through the authenticated notification endpoint"
    );
    assert.strictEqual(
      director.linkTitle,
      notification.data.link_title,
      "the authored link title remains plain text"
    );
  });

  test("omits navigation when the broadcast has no link", function (assert) {
    const director = new CustomNotification({
      ...this.options,
      notification: buildNotification({ has_link: false, link_title: "" }),
    });

    assert.strictEqual(director.linkHref, undefined, "there is no destination");
    assert.strictEqual(
      director.linkTitle,
      i18n("discourse_custom_notifications.notification_title"),
      "the notification still has a useful title"
    );
  });

  test("preserves native behavior for unrelated custom notifications", function (assert) {
    const notification = buildNotification({
      message: "solved.accepted_notification",
      title: "notifications.titles.mentioned",
      topic_title: "A solved topic",
    });
    notification.setProperties({
      topic_id: 17,
      post_number: 3,
      slug: "a-solved-topic",
    });
    const options = { ...this.options, notification };
    const director = new CustomNotification(options);
    const nativeDirector = new NativeCustomNotification(options);

    for (const property of [
      "description",
      "icon",
      "label",
      "linkHref",
      "linkTitle",
    ]) {
      assert.strictEqual(
        director[property],
        nativeDirector[property],
        `${property} keeps the native custom-notification behavior`
      );
    }
  });

  test("keeps HTML-looking notification content as untrusted strings", function (assert) {
    const body = '<img src="x" onerror="alert(1)"> <script>alert(2)</script>';
    const title = '<b onclick="alert(3)">Open</b>';
    const director = new CustomNotification({
      ...this.options,
      notification: buildNotification({ topic_title: body, link_title: title }),
    });

    assert.strictEqual(
      director.description,
      body,
      "the original text is retained"
    );
    assert.false(
      isHTMLSafe(director.description),
      "the body is not trusted HTML"
    );
    assert.strictEqual(
      director.linkTitle,
      title,
      "the title is also plain text"
    );
    assert.false(
      isHTMLSafe(director.linkTitle),
      "the title is not trusted HTML"
    );
  });
});

module(
  "Integration | Component | UserMenu | MenuItem | custom notifications",
  function (hooks) {
    setupRenderingTest(hooks);

    test("escapes authored content in the native notification item", async function (assert) {
      withPluginApi((api) => {
        api.registerNotificationTypeRenderer(
          "custom",
          () => CustomNotification
        );
      });
      this.siteSettings.show_user_menu_avatars = false;
      const body = '<img src="x" onerror="alert(1)"> <script>alert(2)</script>';
      const title = '<b onclick="alert(3)">Open</b>';
      const item = new UserMenuNotificationItem({
        notification: buildNotification({
          topic_title: body,
          link_title: title,
        }),
        currentUser: this.currentUser,
        siteSettings: this.siteSettings,
        site: this.site,
      });

      await render(<template><MenuItem @item={{item}} /></template>);

      assert
        .dom(".item-description")
        .hasText(body, "markup is visible as text");
      assert
        .dom(".item-description img, .item-description script")
        .doesNotExist("authored HTML elements are never inserted");
      assert.dom("li > a").hasAttribute("title", title, "the title is escaped");
      assert
        .dom("li > a")
        .hasAttribute(
          "href",
          getURL("/custom-notifications/42"),
          "the item points to the authenticated redirect"
        );
      assert.dom(".d-icon-bullhorn").exists("the notice icon is displayed");
    });
  }
);
