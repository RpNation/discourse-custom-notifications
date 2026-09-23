import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import CustomNotificationComposer from "discourse/plugins/discourse-custom-notifications/discourse/components/custom-notification-composer";

module(
  "Integration | Component | CustomNotificationComposer",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    hooks.beforeEach(function () {
      this.groups = [{ id: 7, name: "writers" }];
      this.previewRequests = [];
      this.sendRequests = [];
      this.transitions = [];
      this.recipientCount = 2;
      this.owner.lookup("service:router").transitionTo = (...args) => {
        this.transitions.push(args);
      };

      pretender.post("/admin/custom-notifications/preview.json", (request) => {
        const data = parsePostData(request.requestBody);
        this.previewRequests.push(data);
        return response({
          preview_token: `preview-${this.previewRequests.length}`,
          recipient_count: this.recipientCount,
          sample_users:
            this.recipientCount > 0 ? [{ id: 2, username: "user2" }] : [],
          preview: {
            sender_username: data.sender_username,
            message: data.message,
            link_url: data.link_url,
            link_title: data.link_title,
          },
        });
      });

      pretender.post("/admin/custom-notifications.json", (request) => {
        this.sendRequests.push(parsePostData(request.requestBody));
        return response({ broadcast: { id: 23 } });
      });
    });

    test("submitting the form previews recipients without sending", async function (assert) {
      await render(
        <template>
          <CustomNotificationComposer
            @currentUsername="admin"
            @groups={{this.groups}}
          />
        </template>
      );
      const message = '<img src="x" onerror="alert(1)"> Event reminder';
      await formKit().field("message").fillIn(message);
      await formKit().field("username").fillIn("user");
      await formKit().submit();

      assert.strictEqual(
        this.previewRequests.length,
        1,
        "one preview is requested"
      );
      assert.strictEqual(
        this.sendRequests.length,
        0,
        "previewing sends no alerts"
      );
      assert.strictEqual(
        this.previewRequests[0].filters.username,
        "user",
        "recipient filters are included in the preview"
      );
      assert
        .dom(".custom-notifications__body")
        .hasText(message, "the exact message is shown for review");
      assert
        .dom(".custom-notifications__body img")
        .doesNotExist("the preview treats the message as plain text");
      assert
        .dom(".custom-notifications__samples")
        .hasText("user2", "matching sample users are shown");
      assert
        .dom(".custom-notifications__actions .btn-primary")
        .isEnabled("sending requires a separate confirmation");
    });

    test("confirmation sends the reviewed payload with its preview token and request UUID", async function (assert) {
      await render(
        <template>
          <CustomNotificationComposer
            @currentUsername="admin"
            @groups={{this.groups}}
          />
        </template>
      );
      await formKit().field("message").fillIn("The event starts tomorrow.");
      await formKit().field("link_url").fillIn("/t/17");
      await formKit().field("link_title").fillIn("Read the announcement");
      await formKit().field("username").fillIn("user2");
      await formKit().field("username_exact").toggle();
      await formKit().submit();
      await click(".custom-notifications__actions .btn-primary");

      assert.strictEqual(
        this.sendRequests.length,
        1,
        "confirmation submits once"
      );
      const { preview_token, request_id, ...payload } = this.sendRequests[0];
      assert.deepEqual(
        payload,
        this.previewRequests[0],
        "the submitted message and filters match what was reviewed"
      );
      assert.strictEqual(
        preview_token,
        "preview-1",
        "the reviewed audience token is sent"
      );
      assert.true(
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
          request_id
        ),
        "the send carries a UUID for duplicate request protection"
      );
      assert.deepEqual(
        this.transitions,
        [["adminPlugins.show.custom-notifications.show", 23]],
        "successful sends open the delivery history entry"
      );
    });

    test("editing a preview requires another preview before sending", async function (assert) {
      await render(
        <template>
          <CustomNotificationComposer
            @currentUsername="admin"
            @groups={{this.groups}}
          />
        </template>
      );
      await formKit().field("message").fillIn("First draft");
      await formKit().submit();
      await click(".custom-notifications__actions .btn-default");

      assert
        .dom(".custom-notifications__preview")
        .doesNotExist("the previous preview is discarded when editing");
      assert
        .dom(".custom-notifications__actions .btn-primary")
        .doesNotExist("the old confirmation is unavailable");
      assert
        .form()
        .field("message")
        .hasValue("First draft", "the draft is retained");
      await formKit().field("message").fillIn("Updated draft");
      await formKit().field("username").fillIn("user2");
      await formKit().submit();

      assert.strictEqual(
        this.previewRequests.length,
        2,
        "changes receive a new preview"
      );
      assert.strictEqual(
        this.sendRequests.length,
        0,
        "the second preview still does not send"
      );
      assert
        .dom(".custom-notifications__body")
        .hasText("Updated draft", "confirmation shows the latest draft");
      await click(".custom-notifications__actions .btn-primary");

      const { preview_token, request_id, ...payload } = this.sendRequests[0];
      assert.deepEqual(
        payload,
        this.previewRequests[1],
        "only the newly reviewed payload is submitted"
      );
      assert.strictEqual(
        preview_token,
        "preview-2",
        "the old token is not reused"
      );
      assert.true(
        Boolean(request_id),
        "the new preview has a send request identifier"
      );
    });

    test("an empty recipient preview disables confirmation", async function (assert) {
      this.recipientCount = 0;
      await render(
        <template>
          <CustomNotificationComposer
            @currentUsername="admin"
            @groups={{this.groups}}
          />
        </template>
      );
      await formKit().field("message").fillIn("A notice for matching members");
      await formKit().field("username").fillIn("no-matching-user");
      await formKit().submit();

      assert
        .dom(".custom-notifications__actions .btn-primary")
        .isDisabled("there are no matching recipients to notify");
      assert
        .dom(".custom-notifications__samples")
        .doesNotExist("no sample recipients are shown");
      assert.strictEqual(
        this.sendRequests.length,
        0,
        "an empty audience is never sent"
      );
    });
  }
);
