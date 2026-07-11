<template>
  <el-card>
    <div style="margin-bottom: 16px">
      <el-input v-model="userId" placeholder="请输入用户 ID" style="width: 200px; margin-right: 10px" />
      <el-button type="primary" @click="fetchUserById">查询用户</el-button>
    </div>

    <el-table :data="users" border style="width: 100%">
      <el-table-column prop="id" label="ID" width="80" />
      <el-table-column prop="username" label="用户名" />
      <el-table-column prop="password" label="密码" />
    </el-table>
  </el-card>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getAllUser, getUserById } from '../api/user'

const users = ref<any[]>([])
const userId = ref<string>('')

onMounted(() => {
  getAllUser().then((res: any) => {
    const list = res?.data?.data ?? res?.data ?? res ?? []
    users.value = Array.isArray(list) ? list : []
  })
})

function fetchUserById() {
  getUserById(userId.value).then((res: any) => {
    const item = res?.data ?? res
    users.value = [item]
  })
}
</script>
