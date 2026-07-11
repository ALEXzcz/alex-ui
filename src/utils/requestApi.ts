import axios from "axios";
import router from "../router";
import { ElMessage } from "element-plus";

const apiService = axios.create({
  baseURL: "/api",
  timeout: 5000,
});

//请求拦截器
apiService.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("token");
    if (token && config.headers) config.headers["token"] = token;
    return config;
  },
  (error) => {
    console.error("请求错误：", error);
    return Promise.reject(error);
  }
);

//响应拦截器
apiService.interceptors.response.use(
  (success) => {
    if (success.status && success.status === 200) {
      const { code } = success.data;
      if (code === 500 || code === 403 || code === 401 || code === 400) {
        if (code === 401) {
          ElMessage.error("未登录或登录已过期，请重新登录");
          router.replace("/login");
        } else {
          if (success.data.msg) {
            ElMessage.error(success.data.msg);
          }
        }
      } else if (code === 200 && success.data.msg) {
        ElMessage.success(success.data.msg);
      }
    }
    return success.data;
  },
  (error) => {
    const status = error?.response?.status;
    if (status === 504 || status === 404) {
      ElMessage.error("服务器被吃了⊙﹏⊙∥");
    } else if (status === 403) {
      ElMessage.error("权限不足,请联系管理员");
    } else if (status === 401) {
      ElMessage.error("未登录或登录已过期，请重新登录");
      router.replace("/login");
    } else {
      const msg = error?.response?.data?.msg;
      if (msg) {
        ElMessage.error(msg);
      } else {
        ElMessage.error("未知错误");
      }
    }
  }
);

export default apiService;
