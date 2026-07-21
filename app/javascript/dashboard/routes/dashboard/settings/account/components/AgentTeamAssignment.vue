<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();
const isEnabled = ref(false);
const { currentAccount, updateAccount } = useAccount();

watch(
  currentAccount,
  () => {
    const { auto_assign_agent_unique_team: enabled } =
      currentAccount.value?.settings || {};
    isEnabled.value = !!enabled;
  },
  { deep: true, immediate: true }
);

const toggleSetting = async () => {
  try {
    await updateAccount({ auto_assign_agent_unique_team: isEnabled.value });
    useAlert(t('GENERAL_SETTINGS.FORM.AGENT_TEAM_ASSIGNMENT.API.SUCCESS'));
  } catch (error) {
    isEnabled.value = !isEnabled.value;
    useAlert(t('GENERAL_SETTINGS.FORM.AGENT_TEAM_ASSIGNMENT.API.ERROR'));
  }
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.AGENT_TEAM_ASSIGNMENT.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.AGENT_TEAM_ASSIGNMENT.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex justify-end">
        <Switch v-model="isEnabled" @change="toggleSetting" />
      </div>
    </template>
  </SectionLayout>
</template>
