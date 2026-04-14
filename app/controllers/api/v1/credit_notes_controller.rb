module Api
  module V1
    class CreditNotesController < BaseController
      before_action :set_credit_note, only: %i[show update destroy send_to_arca]

      def index
        credit_notes = policy_scope(CreditNote)
          .includes(:client, :sell_point, :client_invoice, lines: :iva)
          .order(date: :desc)
        render json: credit_notes, each_serializer: CreditNoteSerializer
      end

      def show
        authorize @credit_note
        render json: @credit_note, serializer: CreditNoteSerializer
      end

      def next_number
        authorize CreditNote
        render json: { number: CreditNote.current_number(current_user.id, params[:sell_point_id], params[:invoice_type]) }
      end

      # GET /api/v1/credit_notes/create_from_invoice?client_invoice_id=:id
      # Builds an unsaved credit note pre-filled from the invoice. Frontend uses
      # this to populate the form; the user edits number/lines and submits to #create.
      def create_from_invoice
        credit_note = CreditNotes::BuildFromInvoiceService.call(
          user:              current_user,
          client_invoice_id: params[:client_invoice_id],
          date:              Date.current.to_s
        )
        authorize credit_note, :create?

        if credit_note.lines.empty?
          return render_errors([ I18n.t("credit_notes.errors.invoice_fully_credited") ])
        end

        render json: credit_note, serializer: CreditNoteSerializer
      rescue ActiveRecord::RecordNotFound
        render_errors([ I18n.t("client_invoices.flash.not_found") ], status: :not_found)
      end

      def create
        credit_note = CreditNote.new(credit_note_params.merge(user_id: current_user.id))
        credit_note.lines.each { |line| line.user_id = current_user.id if line.user_id.blank? }

        number = credit_note_params[:number].presence ||
                 CreditNote.current_number(current_user.id, credit_note_params[:sell_point_id], credit_note_params[:invoice_type])
        credit_note.number = number

        authorize credit_note

        if credit_note.save
          render json: loaded_credit_note(credit_note.id), serializer: CreditNoteSerializer, status: :created
        else
          render_errors(credit_note.errors.full_messages)
        end
      end

      def update
        authorize @credit_note

        if @credit_note.afip_authorized?
          return render json: {
            error: { code: "cannot_edit", message: I18n.t("credit_notes.errors.cannot_edit_authorized") }
          }, status: :unprocessable_entity
        end

        @credit_note.assign_attributes(credit_note_params)
        @credit_note.lines.each { |line| line.user_id = current_user.id if line.user_id.blank? }

        if @credit_note.save
          render json: @credit_note.reload, serializer: CreditNoteSerializer
        else
          render_errors(@credit_note.errors.full_messages)
        end
      end

      def destroy
        authorize @credit_note

        if @credit_note.afip_authorized?
          return render json: {
            error: { code: "cannot_delete", message: I18n.t("credit_notes.errors.cannot_delete_authorized") }
          }, status: :unprocessable_entity
        end

        @credit_note.destroy!
        head :no_content
      end

      def send_to_arca
        authorize @credit_note

        if @credit_note.authorized?
          return render json: @credit_note, serializer: CreditNoteSerializer
        end

        unless @credit_note.submittable?
          return render json: {
            error: { code: "conflict", message: "Credit note is currently being processed" }
          }, status: :conflict
        end

        result = arca_service_module::SendToArcaService.new(invoice: @credit_note).call

        if result[:success]
          render json: @credit_note.reload, serializer: CreditNoteSerializer
        else
          render json: { errors: Array(result[:errors]) }, status: :unprocessable_entity
        end
      end

      private

      def loaded_credit_note(id)
        CreditNote
          .includes(:client, :sell_point, :client_invoice, lines: :iva)
          .find(id)
      end

      def set_credit_note
        @credit_note = CreditNote
          .kept
          .includes(:client, :sell_point, :client_invoice, lines: :iva)
          .where(user_id: current_user.id)
          .find(params[:id])
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
