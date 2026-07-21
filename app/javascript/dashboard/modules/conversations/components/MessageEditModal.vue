<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  message: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);
const { t } = useI18n();
const store = useStore();
const content = ref(props.message.content);
const isSaving = ref(false);

const cannotSave = computed(
  () =>
    isSaving.value ||
    !content.value?.trim() ||
    content.value === props.message.content
);

const save = async () => {
  isSaving.value = true;
  try {
    await store.dispatch('editMessage', {
      conversationId: props.message.conversation_id,
      messageId: props.message.id,
      content: content.value,
      expectedContent: props.message.content,
    });
    useAlert(t('CONVERSATION.CONTEXT_MENU.EDIT_PENDING'));
    emit('close');
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('CONVERSATION.CONTEXT_MENU.EDIT_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col">
    <woot-modal-header
      :header-title="t('CONVERSATION.CONTEXT_MENU.EDIT_TITLE')"
    />
    <form class="w-full px-5 pb-6 pt-2" @submit.prevent="save">
      <textarea
        v-model="content"
        class="min-h-32 w-full resize-y rounded-lg border border-n-weak bg-n-alpha-2 p-3 text-sm text-n-slate-12 focus:border-n-blue-8 focus:outline-none"
        :placeholder="t('CONVERSATION.CONTEXT_MENU.EDIT_PLACEHOLDER')"
      />
      <div class="flex justify-end gap-2 pt-4">
        <NextButton
          faded
          slate
          type="button"
          :label="t('CONVERSATION.CONTEXT_MENU.EDIT_CANCEL')"
          @click="emit('close')"
        />
        <NextButton
          type="submit"
          :disabled="cannotSave"
          :is-loading="isSaving"
          :label="t('CONVERSATION.CONTEXT_MENU.EDIT_SAVE')"
        />
      </div>
    </form>
  </div>
</template>
