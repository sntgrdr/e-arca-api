module Api
  module V1
    class CommentsController < BaseController
      before_action :set_commentable
      before_action :set_comment, only: [:destroy]

      def index
        skip_policy_scope
        render json: @commentable.comments.order(created_at: :asc),
               each_serializer: CommentSerializer
      end

      def create
        comment = @commentable.comments.build(body: comment_params[:body], user: current_user)
        authorize comment
        if comment.save
          render json: comment, serializer: CommentSerializer, status: :created
        else
          render_errors(comment.errors.full_messages)
        end
      end

      def destroy
        authorize @comment
        @comment.destroy!
        head :no_content
      end

      private

      def set_commentable
        @commentable = if params[:client_invoice_id]
          ClientInvoice.kept.where(user_id: current_user.id).find(params[:client_invoice_id])
        elsif params[:credit_note_id]
          CreditNote.kept.where(user_id: current_user.id).find(params[:credit_note_id])
        elsif params[:client_id]
          Client.where(user_id: current_user.id).find(params[:client_id])
        end
      end

      def set_comment
        @comment = @commentable.comments.find(params[:id])
      end

      def comment_params
        params.require(:comment).permit(:body)
      end
    end
  end
end
