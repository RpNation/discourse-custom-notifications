export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("custom-notifications", { path: "notifications" }, function () {
      this.route("new");
      this.route("show", { path: "/:broadcast_id" });
    });
  },
};
