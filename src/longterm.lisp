;;; Copyright (c) 2014, Jan Winkler <winkler@cs.uni-bremen.de>
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;;
;;; * Redistributions of source code must retain the above copyright
;;; notice, this list of conditions and the following disclaimer.
;;; * Redistributions in binary form must reproduce the above copyright
;;; notice, this list of conditions and the following disclaimer in the
;;; documentation and/or other materials provided with the distribution.
;;; * Neither the name of the Institute for Artificial Intelligence/
;;; Universitaet Bremen nor the names of its contributors may be used to 
;;; endorse or promote products derived from this software without specific 
;;; prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :cram-longterm-pickandplace)

(defun generate-environment-location ()
  "Generated a location designator with random properties as defined
in the function."
  (let* ((possible-locations
           `(,*loc-on-sink-block*
             ,*loc-on-kitchen-island*
             ,*loc-on-cupboard*)))
    (nth (random
          (length possible-locations))
         possible-locations)))

(defun generate-object-acted-on (&key filter-function)
  "Generated an object designator with random properties as defined in
the function."
  (block generator-block
    (loop while t
          for object = (make-designator
                        'object
                        (append (prob-prop 'desig-props::type
                                           `(desig-props::pancakemix
                                             (desig-props::dinnerplate 0.1)
                                             (desig-props::muesli 0.1)
                                             (desig-props::ketchup 0.1))
                                           1.0)
                                (prob-prop 'desig-props::color
                                           `(desig-props::red
                                             (desig-props::blue 0.1)
                                             desig-props::green
                                             desig-props::yellow
                                             desig-props::white)
                                           0.4)
                                (prob-prop 'desig-props::shape
                                          `(desig-props::round
                                            desig-props::flat
                                            desig-props::box)
                                          0.2)
                                `((desig-props:at
                                   ,(generate-environment-location)))))
          when (or (not filter-function)
                   (not (funcall filter-function object)))
            do (return-from generator-block object))))

(defun invalid-object-filter-function (object)
  "Returns `T' when the object passed as `object' is invalid. Valid objects are:
 - `red', `round' `ketchup'
 - `yellow', `box', `muesli'
 - `white', `flat', `dinnerplate'"
  (let ((type (desig-prop-value object 'type))
        (color (desig-prop-value object 'color))
        (shape (desig-prop-value object 'shape)))
    (not (or (and (eql type 'ketchup)
                  (eql color 'red)
                  (eql shape 'round))
             (and (eql type 'muesli)
                  (eql color 'yellow)
                  (eql shape 'box))
             (and (eql type 'dinnerplate)
                  (eql color 'white)
                  (eql shape 'flat))))))

(defun invalid-common-object-filter-function (object)
  (let ((type (desig-prop-value object 'type))
        (color (desig-prop-value object 'color))
        (shape (desig-prop-value object 'shape)))
    (declare (ignorable type color shape))
    (not (or (and (eql type 'pancakemix))
             (and (eql type 'spatula))))))

(def-top-level-cram-function perform-generated-task
    (&key (arms `(:left :right)) (prepare-settings nil))
  (when prepare-settings
    (beliefstate:enable-logging nil)
    (prepare-settings))
  (beliefstate:enable-logging t)
  (with-process-modules
    (ensure-arms-up arms)
    (try-forever
      (let* ((object (generate-object-acted-on
                      :filter-function
                      #'invalid-common-object-filter-function)))
        (try-n-times 3
          (pick-object object))
        (try-forever
          (let* ((location (generate-environment-location)))
            (try-n-times 3
              (place-object object location))))))))

(def-top-level-cram-function longterm (&key (runs 1))
  ;(beliefstate:enable-logging nil)
  ;(prepare-settings)
  ;(beliefstate:enable-logging t)
  (with-process-modules
    (loop for i from 0 below runs
          do (ensure-arms-up)
             (try-forever
               (set-locations)
               (set-objects)
               (let* ((object *pancake-mix*)
                      (putdown-location *loc-on-kitchen-island*))
                 (pick-object object)
                 (place-object object putdown-location))))))

(defun set-objects ()
  (setf *pancake-mix*
        (make-designator
         'object
         `((desig-props:at ,*loc-on-kitchen-island*);,*loc-on-sink-block*)
           (desig-props::type desig-props::pancakemix)
           (desig-props::max-handles 1)
           ,@(mapcar
              (lambda (handle-object)
                `(desig-props:handle ,handle-object))
              (make-handles
               0.04
               :segments 2
               :ax (/ pi 2)
               :offset-angle (/ pi 2)
               :center-offset
               (tf:make-3d-vector 0.02 0.0 0.0)))))))

(def-top-level-cram-function table-setting ()
  (with-process-modules
    (ensure-arms-up)
    (try-forever
      (beliefstate:enable-logging nil)
      (prepare-settings)
      (beliefstate:enable-logging t)
      (with-designators
          ((plate (object `((desig-props::type
                             desig-props::dinnerplate)
                            (desig-props::at
                             ,*loc-on-sink-block*))))
           (milkbox (object `((desig-props::type
                               desig-props::milkbox)
                              (desig-props::at
                             ,*loc-on-sink-block*)))))
        (pick-object milkbox)
        (place-object milkbox *loc-on-kitchen-island*)
        (pick-object plate)
        (place-object plate *loc-on-kitchen-island*)))))

(defun split-by-one-space (string)
  "Returns a list of substrings of string divided by ONE space each.
Note: Two consecutive spaces will be seen as if there were an empty
string between them."
  (loop for i = 0 then (1+ j)
        as j = (position #\Space string :start i)
        collect (subseq string i j)
        while j))

(defun make-location (str)
  (cond
    ((string= str "counter")
     (make-designator
      'location
      `((desig-props:on Cupboard)
        (desig-props:name "kitchen_island"))))
    ((string= str "sink")
     (make-designator
      'location
      `((desig-props:on Cupboard)
        (desig-props:name "kitchen_sink_block"))))))

(defun make-object-at (subject loc-str)
  (let ((loc (make-location loc-str)))
    (when loc
      (cond
        ((string= subject "pancakemix")
         (make-designator
          'object
          `((desig-props:at ,loc)
            (desig-props:type desig-props:pancakemix)
            (desig-props::max-handles 1))))))))

(defun newest-non-effective (designator)
  (cond ((desig:effective designator)
         (newest-non-effective (parent designator)))
        (t designator)))

(def-top-level-cram-function ex (sentence)
  (let ((elements (split-by-one-space sentence)))
    (when elements
      (cond
        ((and (string= (first elements) "move")
              (string= (third elements) "from")
              (string= (fifth elements) "to"))
         (let* ((subject (second elements))
                (from (fourth elements))
                (to (sixth elements))
                (obj (make-object-at subject from))
                (to-loc (make-location to)))
           (when (and obj to-loc)
             (with-process-modules
               (ensure-arms-up)
               (try-forever
                 ;; Rewind the designator to the last, non-effective
                 ;; one when no object could be found.
                 (when (desig:effective obj)
                   (let ((nn-eff (newest-non-effective obj)))
                     (make-designator
                      'object (description nn-eff) obj)))
                 (pick-object obj)
                 (place-object obj to-loc))))))))))

(defun start ()
  (top-level
    (set-locations)
    (set-objects)
    (prepare-settings))
  (longterm))

(defun test-call ()
  `(format t "1~%"))

(defun test-intermediate ()
  (test-call))

(defmacro test-env (&body body)
  `(progn
     (macrolet ((test-call ()
                  `(format t "2~%")))
       ,@body)))

(defun test-macro-defun ()
  (test-intermediate)
  (test-env
    (test-intermediate))
  (test-intermediate))

(def-top-level-cram-function grab-tray ()
  (with-process-modules
    (let ((tray-pose (tf:make-pose-stamped
                      "base_link"
                      0.0
                      (tf:make-3d-vector
                       0.6 0.0 0.82)
                      (tf:make-identity-rotation))))
      (with-designators
          ((tray-loc (location `((desig-props:pose
                                  ,tray-pose))))
           (tray (object `((desig-props:at ,tray-loc)
                           (desig-props:name desig-props::tray)
                           (desig-props:dimensions ,(vector 0.1 0.1 0.1))
                           (desig-props::carry-handles 2)
                           ,@(mapcar (lambda (handle)
                                       `(desig-props:handle ,handle))
                                     (make-handles
                                      0.15 :segments 2
                                           :offset-angle (/ pi 2)
                                           :ay (* (/ pi 4) 3)))))))
        (let ((effective-tray
                (make-effective-designator
                 tray
                 :data-object (make-instance
                               'robosherlock-pm::perceived-object-data
                               :object-identifier 'desig-props::tray
                               :pose tray-pose))))
          (with-designators
              ((grasp-action
                (action
                 `((desig-props:type desig-props:trajectory)
                   (desig-props:to desig-props:grasp)
                   (desig-props:obj ,effective-tray))))
               (lift-action
                (action `((desig-props:type desig-props:trajectory)
                          (desig-props:to desig-props:lift)
                          (desig-props:obj ,effective-tray)))))
            (robosherlock-pm::add-appeared-objects
             (list effective-tray))
            (perform grasp-action)
            (perform lift-action)
            effective-tray))))))

;; (def-top-level-cram-function grab-tray ()
;;   (with-process-modules
;;     (with-designators
;;         ((tray-loc (location `((desig-props:pose
;;                                 ,(tf:make-pose-stamped
;;                                   "base_link"
;;                                   0.0
;;                                   (tf:make-3d-vector
;;                                    0.6 0.0 0.9)
;;                                   (tf:make-identity-rotation))))))
;;          (tray (object `((desig-props:at ,tray-loc)))))
;;     (labels ((relative-linear-arm-translation->trajectory
;;                  (arm rel-position &key (ignore-collisions t)
;;                                      raise-elbow)
;;                (let* ((id-pose
;;                         (tf:pose->pose-stamped
;;                          (case arm
;;                            (:left "l_wrist_roll_link")
;;                            (:right "r_wrist_roll_link"))
;;                          0.0 (tf:make-identity-pose)))
;;                       (tl-pose
;;                         (cl-tf2:ensure-pose-stamped-transformed
;;                          *tf2* id-pose "torso_lift_link"
;;                          :use-current-ros-time t))
;;                       (tl-translated-pose
;;                         (tf:copy-pose-stamped
;;                          tl-pose
;;                          :origin (tf:v+ (tf:origin tl-pose)
;;                                         rel-position))))
;;                  (pr2-manip-pm::arm-pose->trajectory
;;                   arm tl-translated-pose
;;                   :ignore-collisions ignore-collisions
;;                   :raise-elbow (when raise-elbow arm))))
;;              (absolute-arm-pose->trajectory (arm pose-stamped
;;                                              &key raise-elbow
;;                                                ignore-position-check)
;;                (pr2-manip-pm::arm-pose->trajectory
;;                 arm pose-stamped
;;                 :ignore-collisions t
;;                 :raise-elbow (when raise-elbow arm)
;;                 :ignore-position-check ignore-position-check)))
;;       (let ((pregrasp-pose
;;       (moveit:execute-trajectories ;; Move above tray sides
;;        (list (absolute-arm-pose->trajectory
;;               :left (tf:make-pose-stamped
;;                      "base_link" 0.0
;;                      (tf:make-3d-vector 0.6 0.36 1.1)
;;                      (tf:euler->quaternion
;;                       :az (* (/ pi 4) 2)
;;                       :ay (* (/ pi 4) 3)
;;                       :ax (* (/ pi 4) 2)))
;;               :raise-elbow t)
;;              (absolute-arm-pose->trajectory
;;               :right (tf:make-pose-stamped
;;                      "base_link" 0.0
;;                      (tf:make-3d-vector 0.6 -0.36 1.1)
;;                      (tf:euler->quaternion
;;                       :az (* (/ pi 4) 2)
;;                       :ay (* (/ pi 4) 1)
;;                       :ax (* (/ pi 4) 2)))
;;               :raise-elbow t))
;;        :ignore-va t)
;;       (moveit:execute-trajectories ;; Move grippers down onto table surface.
;;        (list (absolute-arm-pose->trajectory
;;               :left (tf:make-pose-stamped
;;                      "base_link" 0.0
;;                      (tf:make-3d-vector 0.6 0.36 0.97)
;;                      (tf:euler->quaternion
;;                       :az (* (/ pi 4) 2)
;;                       :ay (* (/ pi 4) 3)
;;                       :ax (* (/ pi 4) 2)))
;;               :ignore-position-check t
;;               :raise-elbow t)
;;              (absolute-arm-pose->trajectory
;;               :right (tf:make-pose-stamped
;;                       "base_link" 0.0
;;                       (tf:make-3d-vector 0.6 -0.36 0.97)
;;                       (tf:euler->quaternion
;;                        :az (* (/ pi 4) 2)
;;                        :ay (* (/ pi 4) 1)
;;                        :ax (* (/ pi 4) 2)))
;;               :ignore-position-check t
;;               :raise-elbow t))
;;        :ignore-va t)
;;       (moveit:execute-trajectories ;; Move in to tray
;;        (list (absolute-arm-pose->trajectory
;;               :left (tf:make-pose-stamped
;;                      "base_link" 0.0
;;                      (tf:make-3d-vector 0.6 0.30 0.97)
;;                      (tf:euler->quaternion
;;                       :az (* (/ pi 4) 2)
;;                       :ay (* (/ pi 4) 3)
;;                       :ax (* (/ pi 4) 2)))
;;               :ignore-position-check t
;;               :raise-elbow t)
;;              (absolute-arm-pose->trajectory
;;               :right (tf:make-pose-stamped
;;                       "base_link" 0.0
;;                       (tf:make-3d-vector 0.6 -0.30 0.97)
;;                       (tf:euler->quaternion
;;                        :az (* (/ pi 4) 2)
;;                        :ay (* (/ pi 4) 1)
;;                        :ax (* (/ pi 4) 2)))
;;               :ignore-position-check t
;;               :raise-elbow t))
;;        :ignore-va t)
;;       (cpl:par ;; Close grippers
;;         (pr2-manip-pm::close-gripper :left)
;;         (pr2-manip-pm::close-gripper :right))
;;       (moveit:execute-trajectories ;; Move tray 10cm up
;;        (list (relative-linear-arm-translation->trajectory
;;               :left (tf:make-3d-vector 0 0 0.1)
;;               :raise-elbow t)
;;              (relative-linear-arm-translation->trajectory
;;               :right (tf:make-3d-vector 0 0 0.1)
;;               :raise-elbow t))
;;        :ignore-va t)
;;       (moveit:execute-trajectories ;; Move tray 10cm down
;;        (list (relative-linear-arm-translation->trajectory
;;               :left (tf:make-3d-vector 0 0 -0.1)
;;               :raise-elbow t)
;;              (relative-linear-arm-translation->trajectory
;;               :right (tf:make-3d-vector 0 0 -0.1)
;;               :raise-elbow t))
;;        :ignore-va t)
;;       (cpl:par ;; Open grippers
;;         (pr2-manip-pm::open-gripper :left)
;;         (pr2-manip-pm::open-gripper :right))
;;       (moveit:execute-trajectories ;; Move out of tray
;;        (list (absolute-arm-pose->trajectory
;;               :left (tf:make-pose-stamped
;;                      "base_link" 0.0
;;                      (tf:make-3d-vector 0.6 0.36 0.97)
;;                      (tf:euler->quaternion
;;                       :az (* (/ pi 4) 2)
;;                       :ay (* (/ pi 4) 3)
;;                       :ax (* (/ pi 4) 2)))
;;               :ignore-position-check t
;;               :raise-elbow t)
;;              (absolute-arm-pose->trajectory
;;               :right (tf:make-pose-stamped
;;                       "base_link" 0.0
;;                       (tf:make-3d-vector 0.6 -0.36 0.97)
;;                       (tf:euler->quaternion
;;                        :az (* (/ pi 4) 2)
;;                        :ay (* (/ pi 4) 1)
;;                        :ax (* (/ pi 4) 2)))
;;               :ignore-position-check t
;;               :raise-elbow t))
;;        :ignore-va t)
;;       (moveit:execute-trajectories ;; Move above tray sides
;;        (list (absolute-arm-pose->trajectory
;;               :left (tf:make-pose-stamped
;;                      "base_link" 0.0
;;                      (tf:make-3d-vector 0.6 0.36 1.1)
;;                      (tf:euler->quaternion
;;                       :az (* (/ pi 4) 2)
;;                       :ay (* (/ pi 4) 3)
;;                       :ax (* (/ pi 4) 2)))
;;               :raise-elbow t)
;;              (absolute-arm-pose->trajectory
;;               :right (tf:make-pose-stamped
;;                      "base_link" 0.0
;;                      (tf:make-3d-vector 0.6 -0.36 1.1)
;;                      (tf:euler->quaternion
;;                       :az (* (/ pi 4) 2)
;;                       :ay (* (/ pi 4) 1)
;;                       :ax (* (/ pi 4) 2)))
;;               :raise-elbow t))
;;        :ignore-va t))))
