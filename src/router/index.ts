import { createRouter, createWebHistory } from "vue-router";
import UserInfoView from "../views/UserInfoView.vue";

const routes = [
  {
    path: "/",
    name: "user-info",
    component: UserInfoView, // 设置组件
  },
];

const router = createRouter({
  history: createWebHistory('/alex/'),
  routes,
});

export default router;
