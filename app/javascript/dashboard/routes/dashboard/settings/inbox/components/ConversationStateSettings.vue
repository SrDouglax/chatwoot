<script setup>
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';

const modelValue = defineModel({ type: Boolean, default: false });
</script>

<template>
  <SettingsToggleSection
    v-model="modelValue"
    :header="$t('INBOX_MGMT.SETTINGS_POPUP.SIMPLIFIED_CONVERSATION_STATUSES')"
    :description="
      $t('INBOX_MGMT.SETTINGS_POPUP.SIMPLIFIED_CONVERSATION_STATUSES_SUB_TEXT')
    "
  />
</template>
