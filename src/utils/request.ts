import axios from "axios";

const service = axios.create({
  baseURL: "/api",
  timeout: 5000,
});

//请求拦截器
service.interceptors.request.use(
  (config) => {
    return config;
  },
  (error) => {
    console.error("请求错误：", error);
    return Promise.reject(error);
  }
);
export default service;
