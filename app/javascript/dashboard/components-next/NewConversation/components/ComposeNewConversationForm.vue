<script setup>
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, requiredIf } from '@vuelidate/validators';
import { INBOX_TYPES, isVoiceCallEnabled } from 'dashboard/helper/inbox';
import { useStore } from 'dashboard/composables/store';
import {
  appendSignature,
  removeSignature,
  getEffectiveChannelType,
  stripUnsupportedMarkdown,
} from 'dashboard/helper/editorHelper';
import {
  buildContactableInboxesList,
  prepareNewMessagePayload,
  prepareWhatsAppMessagePayload,
} from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper.js';

import { useCopilotReply } from 'dashboard/composables/useCopilotReply';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

import ContactSelector from './ContactSelector.vue';
import InboxSelector from './InboxSelector.vue';
import EmailOptions from './EmailOptions.vue';
import MessageEditor from './MessageEditor.vue';
import ActionButtons from './ActionButtons.vue';
import InboxEmptyState from './InboxEmptyState.vue';
import AttachmentPreviews from './AttachmentPreviews.vue';
import CopilotReplyBottomPanel from 'dashboard/components/widgets/WootWriter/CopilotReplyBottomPanel.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contacts: { type: Array, default: () => [] },
  contactId: { type: String, default: null },
  selectedContact: { type: Object, default: null },
  targetInbox: { type: Object, default: null },
  currentUser: { type: Object, default: null },
  isCreatingContact: { type: Boolean, default: false },
  isFetchingInboxes: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  isDirectUploadsEnabled: { type: Boolean, default: false },
  contactConversationsUiFlags: { type: Object, default: null },
  contactsUiFlags: { type: Object, default: null },
  messageSignature: { type: String, default: '' },
  sendWithSignature: { type: Boolean, default: false },
  formState: { type: Object, required: true },
});

const emit = defineEmits([
  'searchContacts',
  'resetContactSearch',
  'discard',
  'updateSelectedContact',
  'updateTargetInbox',
  'clearSelectedContact',
  'createConversation',
]);

const DEFAULT_FORMATTING = 'Context::Default';

const copilot = useCopilotReply();
const store = useStore();
const router = useRouter();
const { t } = useI18n();

const showContactsDropdown = ref(false);
const showInboxesDropdown = ref(false);
const showCcEmailsDropdown = ref(false);
const showBccEmailsDropdown = ref(false);
const existingConversationDialogRef = ref(null);
const existingConversation = ref(null);
const pendingConversationRequest = ref(null);

const isCreating = computed(() => props.contactConversationsUiFlags.isCreating);
const shouldWarnOnExistingConversation = computed(
  () => props.targetInbox?.warnOnExistingConversation
);

const state = props.formState || {
  message: '',
  subject: '',
  ccEmails: '',
  bccEmails: '',
  attachedFiles: [],
};

const inboxTypes = computed(() => ({
  isEmail: props.targetInbox?.channelType === INBOX_TYPES.EMAIL,
  isTwilio: props.targetInbox?.channelType === INBOX_TYPES.TWILIO,
  isWhatsapp: props.targetInbox?.channelType === INBOX_TYPES.WHATSAPP,
  isWebWidget: props.targetInbox?.channelType === INBOX_TYPES.WEB,
  isApi: props.targetInbox?.channelType === INBOX_TYPES.API,
  isEmailOrWebWidget:
    props.targetInbox?.channelType === INBOX_TYPES.EMAIL ||
    props.targetInbox?.channelType === INBOX_TYPES.WEB,
  isTwilioSMS:
    props.targetInbox?.channelType === INBOX_TYPES.TWILIO &&
    props.targetInbox?.medium === 'sms',
  isTwilioWhatsapp:
    props.targetInbox?.channelType === INBOX_TYPES.TWILIO &&
    props.targetInbox?.medium === 'whatsapp',
}));

const whatsappMessageTemplates = computed(() =>
  Object.keys(props.targetInbox?.messageTemplates || {}).length
    ? props.targetInbox.messageTemplates
    : []
);

const inboxChannelType = computed(() => props.targetInbox?.channelType || '');

const inboxMedium = computed(() => props.targetInbox?.medium || '');

const voiceCallEnabled = computed(() => isVoiceCallEnabled(props.targetInbox));

const effectiveChannelType = computed(() =>
  getEffectiveChannelType(inboxChannelType.value, inboxMedium.value)
);

const validationRules = computed(() => ({
  selectedContact: { required },
  targetInbox: { required },
  message: { required: requiredIf(!inboxTypes.value.isWhatsapp) },
  subject: { required: requiredIf(inboxTypes.value.isEmail) },
}));

const v$ = useVuelidate(validationRules, {
  selectedContact: computed(() => props.selectedContact),
  targetInbox: computed(() => props.targetInbox),
  message: computed(() => state.message),
  subject: computed(() => state.subject),
});

const validationStates = computed(() => ({
  isContactInvalid:
    v$.value.selectedContact.$dirty && v$.value.selectedContact.$invalid,
  isInboxInvalid: v$.value.targetInbox.$dirty && v$.value.targetInbox.$invalid,
  isSubjectInvalid: v$.value.subject.$dirty && v$.value.subject.$invalid,
  isMessageInvalid: v$.value.message.$dirty && v$.value.message.$invalid,
}));

const newMessagePayload = () => {
  const { message, subject, ccEmails, bccEmails, attachedFiles } = state;
  return prepareNewMessagePayload({
    targetInbox: props.targetInbox,
    selectedContact: props.selectedContact,
    message,
    subject,
    ccEmails,
    bccEmails,
    currentUser: props.currentUser,
    attachedFiles,
    directUploadsEnabled: props.isDirectUploadsEnabled,
  });
};

const contactableInboxesList = computed(() => {
  return buildContactableInboxesList(props.selectedContact?.contactInboxes);
});

const showNoInboxAlert = computed(() => {
  return (
    props.selectedContact &&
    contactableInboxesList.value.length === 0 &&
    !props.contactsUiFlags.isFetchingInboxes &&
    !props.isFetchingInboxes
  );
});

const isAnyDropdownActive = computed(() => {
  return (
    showContactsDropdown.value ||
    showInboxesDropdown.value ||
    showCcEmailsDropdown.value ||
    showBccEmailsDropdown.value
  );
});

const handleContactSearch = value => {
  showContactsDropdown.value = value.trim().length > 1;
  emit('searchContacts', value);
};

const handleDropdownUpdate = (type, value) => {
  if (type === 'cc') {
    showCcEmailsDropdown.value = value;
  } else if (type === 'bcc') {
    showBccEmailsDropdown.value = value;
  } else {
    showContactsDropdown.value = value;
  }
};

const searchCcEmails = value => {
  showBccEmailsDropdown.value = false;
  emit('resetContactSearch');
  showCcEmailsDropdown.value = value.trim().length >= 2;
  emit('searchContacts', value);
};

const searchBccEmails = value => {
  showCcEmailsDropdown.value = false;
  emit('resetContactSearch');
  showBccEmailsDropdown.value = value.trim().length >= 2;
  emit('searchContacts', value);
};

const setSelectedContact = async ({ value, action, ...rest }) => {
  v$.value.$reset();
  emit('updateSelectedContact', { value, action, ...rest });
  showContactsDropdown.value = false;
  showInboxesDropdown.value = true;
};

const stripMessageFormatting = channelType => {
  if (!state.message || !channelType) return;

  state.message = stripUnsupportedMarkdown(state.message, channelType, false);
};

const handleInboxAction = ({ value, action, channelType, medium, ...rest }) => {
  v$.value.$reset();
  copilot.reset(false);

  // Strip unsupported formatting when changing the target inbox
  if (channelType) {
    const newChannelType = getEffectiveChannelType(channelType, medium);
    stripMessageFormatting(newChannelType);
  }

  emit('updateTargetInbox', { ...rest, channelType, medium });
  showInboxesDropdown.value = false;
  state.attachedFiles = [];
};

const removeSignatureFromMessage = () => {
  // Always remove the signature from message content when inbox/contact is removed
  // to ensure no leftover signature content remains
  if (props.messageSignature) {
    state.message = removeSignature(
      state.message,
      props.messageSignature,
      effectiveChannelType.value
    );
  }
};

const removeTargetInbox = value => {
  v$.value.$reset();
  copilot.reset(false);
  removeSignatureFromMessage();

  stripMessageFormatting(DEFAULT_FORMATTING);

  emit('updateTargetInbox', value);
  state.attachedFiles = [];
};

const clearSelectedContact = () => {
  copilot.reset(false);
  removeSignatureFromMessage();
  emit('clearSelectedContact');
  state.message = '';
  state.attachedFiles = [];
};

const onClickInsertEmoji = emoji => {
  state.message += emoji;
};

const handleAddSignature = signature => {
  state.message = appendSignature(
    state.message,
    signature,
    effectiveChannelType.value
  );
};

const handleRemoveSignature = signature => {
  state.message = removeSignature(
    state.message,
    signature,
    effectiveChannelType.value
  );
};

const handleAttachFile = files => {
  state.attachedFiles = files;
};

const clearForm = () => {
  copilot.reset(false);
  Object.assign(state, {
    message: '',
    subject: '',
    ccEmails: '',
    bccEmails: '',
    attachedFiles: [],
  });
  v$.value.$reset();
};

const createConversation = async request => {
  await emit('createConversation', request);
};

const findExistingConversation = async () => {
  if (!shouldWarnOnExistingConversation.value) return null;

  return store.dispatch('contactConversations/getLatestByContactAndInbox', {
    contactId: props.selectedContact.id,
    inboxId: props.targetInbox.id,
  });
};

const requestCreateConversation = async request => {
  let conversation = null;
  try {
    conversation = await findExistingConversation();
  } catch (error) {
    await createConversation(request);
    return;
  }

  if (conversation) {
    existingConversation.value = conversation;
    pendingConversationRequest.value = request;
    existingConversationDialogRef.value?.open();
    return;
  }

  await createConversation(request);
};

const handleSendMessage = async () => {
  const isValid = await v$.value.$validate();
  if (!isValid) return;

  const request = {
    payload: newMessagePayload(),
    isFromWhatsApp: false,
  };
  try {
    const success = await requestCreateConversation(request);
    if (success) {
      clearForm();
    }
  } catch (error) {
    // Form will not be cleared if conversation creation fails
  }
};

const handleSendWhatsappMessage = async ({ message, templateParams }) => {
  const whatsappMessagePayload = prepareWhatsAppMessagePayload({
    targetInbox: props.targetInbox,
    selectedContact: props.selectedContact,
    message,
    templateParams,
    currentUser: props.currentUser,
  });
  await requestCreateConversation({
    payload: whatsappMessagePayload,
    isFromWhatsApp: true,
  });
};

const handleSendTwilioMessage = async ({ message, templateParams }) => {
  const twilioMessagePayload = prepareWhatsAppMessagePayload({
    targetInbox: props.targetInbox,
    selectedContact: props.selectedContact,
    message,
    templateParams,
    currentUser: props.currentUser,
  });
  await requestCreateConversation({
    payload: twilioMessagePayload,
    isFromWhatsApp: true,
  });
};

const resetExistingConversationDialog = () => {
  existingConversation.value = null;
  pendingConversationRequest.value = null;
};

const handleSendAnyway = async () => {
  const request = pendingConversationRequest.value;
  existingConversationDialogRef.value?.close();
  resetExistingConversationDialog();
  if (!request) return;

  await createConversation({
    ...request,
    payload: { ...request.payload, forceNewConversation: true },
  });
};

const handleViewExistingConversation = () => {
  const conversation = existingConversation.value;
  existingConversationDialogRef.value?.close();
  resetExistingConversationDialog();
  if (!conversation) return;

  emit('discard');
  router.push(
    `/app/accounts/${conversation.accountId}/conversations/${conversation.id}`
  );
};

const shouldShowMessageEditor = computed(() => {
  return (
    !inboxTypes.value.isWhatsapp &&
    !showNoInboxAlert.value &&
    !inboxTypes.value.isTwilioWhatsapp
  );
});

const isCopilotActive = computed(() => copilot.isActive?.value ?? false);

const onSubmitCopilotReply = () => {
  const acceptedMessage = copilot.accept();
  state.message = acceptedMessage;
};

useKeyboardEvents({
  '$mod+Enter': {
    action: () => {
      if (isCopilotActive.value && !copilot.isButtonDisabled.value) {
        onSubmitCopilotReply();
      }
    },
    allowOnFocusedInput: true,
  },
});
</script>

<template>
  <div
    class="w-full md:w-[42rem] divide-y divide-n-strong overflow-visible transition-all duration-300 ease-in-out top-full flex flex-col bg-n-alpha-3 border border-n-strong shadow-sm backdrop-blur-[100px] rounded-xl min-w-0 max-h-[calc(100vh-8rem)]"
  >
    <div class="flex-1 overflow-y-auto divide-y divide-n-strong">
      <ContactSelector
        :contacts="contacts"
        :selected-contact="selectedContact"
        :show-contacts-dropdown="showContactsDropdown"
        :is-loading="isLoading"
        :is-creating-contact="isCreatingContact"
        :contact-id="contactId"
        :contactable-inboxes-list="contactableInboxesList"
        :show-inboxes-dropdown="showInboxesDropdown"
        :has-errors="validationStates.isContactInvalid"
        @search-contacts="handleContactSearch"
        @set-selected-contact="setSelectedContact"
        @clear-selected-contact="clearSelectedContact"
        @update-dropdown="handleDropdownUpdate"
      />
      <InboxEmptyState v-if="showNoInboxAlert" />
      <InboxSelector
        v-else
        :target-inbox="targetInbox"
        :selected-contact="selectedContact"
        :show-inboxes-dropdown="showInboxesDropdown"
        :contactable-inboxes-list="contactableInboxesList"
        :has-errors="validationStates.isInboxInvalid"
        :is-fetching-inboxes="isFetchingInboxes"
        @update-inbox="removeTargetInbox"
        @toggle-dropdown="showInboxesDropdown = $event"
        @handle-inbox-action="handleInboxAction"
      />

      <EmailOptions
        v-if="inboxTypes.isEmail"
        v-model:cc-emails="state.ccEmails"
        v-model:bcc-emails="state.bccEmails"
        v-model:subject="state.subject"
        :contacts="contacts"
        :show-cc-emails-dropdown="showCcEmailsDropdown"
        :show-bcc-emails-dropdown="showBccEmailsDropdown"
        :is-loading="isLoading"
        :has-errors="validationStates.isSubjectInvalid"
        @search-cc-emails="searchCcEmails"
        @search-bcc-emails="searchBccEmails"
        @update-dropdown="handleDropdownUpdate"
      />

      <MessageEditor
        v-if="shouldShowMessageEditor"
        v-model="state.message"
        :message-signature="messageSignature"
        :send-with-signature="sendWithSignature"
        :has-errors="validationStates.isMessageInvalid"
        :channel-type="inboxChannelType"
        :medium="targetInbox?.medium || ''"
        :copilot="copilot"
      />

      <AttachmentPreviews
        v-if="state.attachedFiles.length > 0"
        :attachments="state.attachedFiles"
        @update:attachments="state.attachedFiles = $event"
      />
    </div>

    <CopilotReplyBottomPanel
      v-if="isCopilotActive"
      :is-generating-content="copilot.isButtonDisabled.value"
      class="h-[3.25rem] !px-4 !py-2"
      @submit="onSubmitCopilotReply"
      @cancel="copilot.reset"
    />
    <ActionButtons
      v-else
      :attached-files="state.attachedFiles"
      :is-whatsapp-inbox="inboxTypes.isWhatsapp"
      :is-email-or-web-widget-inbox="inboxTypes.isEmailOrWebWidget"
      :is-twilio-sms-inbox="inboxTypes.isTwilioSMS"
      :is-twilio-whats-app-inbox="inboxTypes.isTwilioWhatsapp"
      :message-templates="whatsappMessageTemplates"
      :channel-type="inboxChannelType"
      :voice-enabled="voiceCallEnabled"
      :is-loading="isCreating"
      :disable-send-button="isCreating"
      :has-selected-inbox="!!targetInbox"
      :inbox-id="targetInbox?.id"
      :has-no-inbox="showNoInboxAlert"
      :is-dropdown-active="isAnyDropdownActive"
      :message-signature="messageSignature"
      @insert-emoji="onClickInsertEmoji"
      @add-signature="handleAddSignature"
      @remove-signature="handleRemoveSignature"
      @attach-file="handleAttachFile"
      @discard="$emit('discard')"
      @send-message="handleSendMessage"
      @send-whatsapp-message="handleSendWhatsappMessage"
      @send-twilio-message="handleSendTwilioMessage"
    />

    <Dialog
      ref="existingConversationDialogRef"
      :title="t('COMPOSE_NEW_CONVERSATION.FORM.EXISTING_CONVERSATION.TITLE')"
      :description="
        t('COMPOSE_NEW_CONVERSATION.FORM.EXISTING_CONVERSATION.DESCRIPTION')
      "
      width="md"
      @close="resetExistingConversationDialog"
    >
      <template #footer>
        <div class="flex items-center justify-between w-full gap-3">
          <Button
            variant="faded"
            color="slate"
            type="button"
            class="w-full"
            :label="
              t(
                'COMPOSE_NEW_CONVERSATION.FORM.EXISTING_CONVERSATION.SEND_ANYWAY'
              )
            "
            @click="handleSendAnyway"
          />
          <Button
            color="blue"
            type="button"
            class="w-full"
            :label="
              t(
                'COMPOSE_NEW_CONVERSATION.FORM.EXISTING_CONVERSATION.VIEW_CONVERSATION'
              )
            "
            @click="handleViewExistingConversation"
          />
        </div>
      </template>
    </Dialog>
  </div>
</template>
