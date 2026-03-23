# frozen_string_literal: true

class Notes
  # Immutable note record.
  Note = Data.define(:id, :title, :content, :updated_at) do
    def to_h
      {id: id, title: title, content: content, updated_at: updated_at}
    end
  end
end
