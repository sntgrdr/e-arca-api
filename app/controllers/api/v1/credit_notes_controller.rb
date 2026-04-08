module Api
  module V1
    class CreditNotesController < BaseController
      before_action :set_credit_note, only: %i[show update destroy send_to_arca]

      def index
        credit_notes = CreditNote.where(user_id: current_user.id).order(date: :desc)
        render json: credit_notes, each_serializer: CreditNoteSerializer
      end

      def show
        render json: @credit_note, serializer: CreditNoteSerializer
      end

      def next_number
        render json: { number: CreditNote.current_number(current_user.id, params[:sell_point_id]) }
      end

      def create
        credit_note = CreditNote.new(credit_note_params.merge(user_id: current_user.id))

        if credit_note.save
          render json: credit_note, serializer: CreditNoteSerializer, status: :created
        else
          render_errors(credit_note.errors.full_messages)
        end
      end

      def update
        if @credit_note.update(credit_note_params)
          render json: @credit_note, serializer: CreditNoteSerializer
        else
          render_errors(@credit_note.errors.full_messages)
        end
      end

      def destroy
        @credit_note.destroy!
        head :no_content
      end

      def send_to_arca
        if @credit_note.cae.present?
          return render json: { errors: ['La nota de crédito ya fue enviada a ARCA.'] }, status: :unprocessable_entity
        end

        result = "Invoices::#{Rails.env.camelize}::SendToArcaService".constantize.new(invoice: @credit_note).call

        if result[:success]
          render json: @credit_note.reload, serializer: CreditNoteSerializer
        else
          render json: { errors: Array(result[:errors]) }, status: :unprocessable_entity
        end
      end

      private

      def set_credit_note
        @credit_note = CreditNote.where(user_id: current_user.id).find(params[:id])
      end

      def credit_note_params
        params.require(:credit_note).permit(
          :number, :date, :invoice_type, :details, :total_price,
          :sell_point_id, :client_id, :client_invoice_id, :period,
          lines_attributes: [
            :id, :item_id, :description, :quantity,
            :unit_price, :final_price, :user_id, :iva_id, :_destroy
          ]
        )
      end
    end
  end
end
