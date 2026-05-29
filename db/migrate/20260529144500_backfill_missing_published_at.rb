class BackfillMissingPublishedAt < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE entries
      SET published_at = COALESCE(created_at, CURRENT_TIMESTAMP)
      WHERE status = 1 AND published_at IS NULL
    SQL
  end

  def down
    # This backfill preserves existing public URLs; reversing it would hide content.
  end
end
