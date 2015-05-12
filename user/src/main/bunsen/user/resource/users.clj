(ns bunsen.user.resource.users
  (:require [liberator.core :refer [defresource]]
            [bunsen.user.resource.defaults :refer [defaults]]
            [liberator.representation :refer [ring-response]]
            [bunsen.user.model.user :as u]
            [clojure.string :as str]
            [bunsen.user.helper.tsusers :as extuser]))

(defresource users [_] defaults
  :allowed-methods #{:post :get}

  :exists? (fn [{{db :db {id :id} :route-params conn :conn remote-user :remote-user} :request}]
             (if remote-user
                (when-let [user (u/ext-load-user db remote-user conn)]
                 (let [extuser (extuser/get-ext-user (first (str/split remote-user #"@")))
                       mergeduser (extuser/merge-user user extuser)]
                   {::user mergeduser}))
                (when id
                  (when-let [user (u/load-user db id)]
                    {::user user}))))

  :handle-ok ::user

  ; validate user params
  :processable? (fn [{{db :db params :params method :request-method remote-user :remote-user} :request}]
                  (if (= :post method)
                    (if remote-user
                      {::errors "cannot edit external users"}
                      (let [errors (u/validate-user db nil params)]
                        [(empty? errors) {::errors errors}]))
                    true))

  ; respond with validation errors
  :handle-unprocessable-entity ::errors

  :post! (fn [{{conn :conn params :params} :request}]
           (if-let [user (u/create-user! conn (dissoc params :role))]
             {::user user}))

  ; write session cookie
  :handle-created (fn [{{params :params} :request user ::user}]
                    (let [session {:id (:user/public-id user)
                                   :role (:user/role user)}]
                      (ring-response {:session session}))))
