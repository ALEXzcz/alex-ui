import service from "../utils/requestApi";

export function getAllUser(pageNum = 1, pageSize = 10) {
  return service({
    url: "/users/getAllUser",
    method: "get",
    params: { pageNum, pageSize },
  });
}

export function getUserById(userId: string | number) {
  return service({
    url: `/users/${userId}`,
    method: "get",
  });
}

export function updateUser(data: any) {
  return service({
    url: "/users/updateUser",
    method: "post",
    data: { data },
  });
}

export function insertUser(data: any) {
  return service({
    url: "/users/insertUser",
    method: "post",
    data: { data },
  });
}
