<template>
  <RouterView v-slot="{ Component, route }">
    <component :is="Component" v-if="route.path === '/login'" />
    <MainLayout v-else>
      <component :is="Component" />
    </MainLayout>
  </RouterView>
</template>

<script setup>
import MainLayout from './layout/MainLayout.vue'
</script>
