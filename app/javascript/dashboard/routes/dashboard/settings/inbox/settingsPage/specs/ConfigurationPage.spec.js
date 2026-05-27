import { shallowMount } from '@vue/test-utils';
import { vi } from 'vitest';
import ConfigurationPage from '../ConfigurationPage.vue';

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

const createWrapper = inbox => {
  const dispatch = vi.fn(() => Promise.resolve());

  const wrapper = shallowMount(ConfigurationPage, {
    props: { inbox },
    global: {
      mocks: {
        $store: { dispatch },
        $t: key => key,
      },
      stubs: {
        SettingsToggleSection: {
          props: ['header', 'description', 'modelValue'],
          template:
            '<div class="settings-toggle-section">{{ header }}{{ description }}</div>',
        },
        'woot-code': true,
        'woot-input': true,
      },
    },
  });

  return { wrapper, dispatch };
};

describe('ConfigurationPage', () => {
  const whatsappInbox = {
    id: 7,
    channel_type: 'Channel::Whatsapp',
    provider: 'default',
    provider_config: {
      api_key: 'existing-key',
      append_agent_name: true,
    },
  };

  it('renders the agent name toggle for whatsapp inboxes', async () => {
    const { wrapper } = createWrapper(whatsappInbox);

    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();

    expect(wrapper.html()).toContain(
      'INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_APPEND_AGENT_NAME.LABEL'
    );
  });

  it('hydrates the current append_agent_name value from provider_config', async () => {
    const { wrapper } = createWrapper(whatsappInbox);

    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.appendAgentName).toBe(true);
  });

  it('updates the whatsapp provider config when the toggle changes', async () => {
    const { wrapper, dispatch } = createWrapper({
      ...whatsappInbox,
      provider_config: {
        api_key: 'existing-key',
        append_agent_name: false,
      },
    });

    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();
    dispatch.mockClear();

    wrapper.vm.appendAgentName = true;
    await wrapper.vm.$nextTick();
    await Promise.resolve();

    expect(dispatch).toHaveBeenCalledWith('inboxes/updateInbox', {
      id: 7,
      formData: false,
      channel: {
        provider_config: {
          api_key: 'existing-key',
          append_agent_name: true,
        },
      },
    });
  });

  it('preserves the local toggle state when the api key is saved before props refresh', async () => {
    const { wrapper, dispatch } = createWrapper({
      ...whatsappInbox,
      provider_config: {
        api_key: 'existing-key',
        append_agent_name: false,
      },
    });

    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();
    dispatch.mockClear();

    wrapper.vm.appendAgentName = true;
    await wrapper.vm.$nextTick();
    await Promise.resolve();

    wrapper.vm.whatsAppInboxAPIKey = 'new-key';
    await wrapper.vm.updateWhatsAppInboxAPIKey();

    expect(dispatch).toHaveBeenLastCalledWith('inboxes/updateInbox', {
      id: 7,
      formData: false,
      channel: {
        provider_config: {
          api_key: 'new-key',
          append_agent_name: true,
        },
      },
    });
  });

  it('does not render the toggle for non-whatsapp inboxes', async () => {
    const { wrapper } = createWrapper({
      id: 9,
      channel_type: 'Channel::WebWidget',
      provider_config: {},
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.html()).not.toContain(
      'INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_APPEND_AGENT_NAME.LABEL'
    );
  });
});
