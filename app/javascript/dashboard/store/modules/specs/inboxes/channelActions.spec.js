import { buildInboxData } from '../../inboxes/channelActions';

describe('#buildInboxData', () => {
  it('serializes nested API channel attributes', () => {
    const formData = buildInboxData({
      channel: {
        additional_attributes: {
          message_editing_enabled: true,
          message_templates: [{ name: 'welcome' }],
        },
      },
    });

    expect(
      formData.get('channel[additional_attributes][message_editing_enabled]')
    ).toBe('true');
    expect(
      formData.get('channel[additional_attributes][message_templates][][name]')
    ).toBe('welcome');
    expect(formData.get('channel[additional_attributes]')).toBeNull();
  });
});
