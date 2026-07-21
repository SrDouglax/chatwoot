# frozen_string_literal: true

class CreateMessageEditOperations < ActiveRecord::Migration[7.1]
  def change
    create_table :message_edit_operations do |t|
      t.uuid :uuid, default: -> { 'gen_random_uuid()' }, null: false
      t.references :message, null: false, foreign_key: true, type: :integer
      t.references :editor, null: false, foreign_key: { to_table: :users }, type: :bigint
      t.text :previous_content, null: false
      t.text :new_content, null: false
      t.integer :status, default: 0, null: false
      t.string :error_code
      t.timestamps
    end

    add_index :message_edit_operations, :uuid, unique: true
    add_index :message_edit_operations, :message_id, unique: true, where: 'status = 0',
                                                           name: 'index_message_edits_on_pending_message'
  end
end
