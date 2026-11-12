<script setup>
import AppHeader from '../components/AppHeader.vue'
import AppSidebar from '../components/AppSidebar.vue'
</script>

<template>
  <div class="layout">

    <AppSidebar />

    <div class="main">

      <AppHeader />

      <main class="content">
        <slot />
      </main>

    </div>

  </div>
</template>

<style scoped>
.layout{
  display:flex;
  width:100%;
  height:100vh;
  overflow:hidden;
  background:#f4f2ec;
}

.main{
  flex:1;
  display:flex;
  flex-direction:column;
  min-width:0;
  height:100vh;
}

.content{
  flex:1;
  overflow-y:auto;
  overflow-x:hidden;
  padding:28px;
  background:
    radial-gradient(circle at top right,#fbfaf7 0%,#f4f2ec 70%);
}

.sidebar{
  width:300px;
  min-width:300px;
  max-width:300px;

  height:100vh;

  display:flex;
  flex-direction:column;

  overflow:hidden;

  position:sticky;
  top:0;

  background:
    radial-gradient(circle at bottom, rgba(255,255,255,.30), transparent 30%),
    linear-gradient(180deg,#1b1a18 0%,#292720 38%,#151515 100%);
}

@media (max-width:768px){

  .content{
    padding:18px;
  }

}
</style>
