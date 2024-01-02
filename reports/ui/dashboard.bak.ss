(import :std/net/httpd/mux :std/net/httpd :std/net/uri)

(import :std/tal :std/db/dbi :ecm/user/database :ecm/user/entity)
(import ./utils ../../httpd/handler)

(define-TAL (dashboard.html summaries open-claims) file: "./html/dashboard.html")

(define-file dashboard.css "./css/dashboard.css")

(def (handle-dashboard.css _ res)
  (http-response-write res 200 `(("Content-Type" . "text/css")) dashboard.css))

(define-file chartScripts.js "./js/chartScripts.js")

(def (handle-chartScripts.js _ res)
  (http-response-write
   res 200 `(("Content-Type" . "text/javascript")) chartScripts.js))

(def open-diff-sql #<<EOF
  SELECT *, percentage_change(master_this_week::int, master_last_week::int) AS percentage_diff
  FROM (SELECT opened_this_week - children_this_week AS master_this_week,
         opened_last_week - children_last_week AS master_last_week
  FROM
  (SELECT (this_week).*, opened_last_week, children_last_week
  FROM (SELECT this_week, count(claim_id) AS opened_last_week,
         count(group_leader_id) AS children_last_week
  FROM
   (SELECT rng.start, rng.end,
         count(this_week.claim_id) AS opened_this_week,
         count(this_week.group_leader_id) AS children_this_week
   FROM (SELECT (e.end - interval '1 week') AS start,
       	      e.end FROM (SELECT now() - interval '1 week' AS end) e) rng
   LEFT JOIN claim this_week
   ON (this_week.open_date::timestamp with time zone <@ tstzrange(rng.end, now()))
   GROUP BY "start", "end") this_week
   LEFT JOIN claim last_week
   ON (last_week.open_date::timestamp with time zone <@ tstzrange(this_week.start, this_week.end))
   GROUP BY this_week) wkd) rep) master
EOF
)

(def hours-logged-diff-sql #<<EOF
  SELECT hours_logged_this_week, hours_logged_last_week,
              percentage_change(hours_logged_this_week, hours_logged_last_week)
  FROM (SELECT (this_week).hours_logged_this_week, hours_logged_last_week
   FROM (SELECT this_week, sum(last_week.minutes) AS hours_logged_last_week
    FROM (SELECT rng, sum(minutes) AS hours_logged_this_week
     FROM timecard this_week JOIN
      (SELECT (e.end - interval '1 week') AS start, e.end FROM
       (SELECT now() - interval '1 week' AS end) e) rng ON (this_week.date > rng.end)
         WHERE this_week.date IS NOT NULL GROUP BY rng) this_week
         LEFT JOIN timecard last_week
         ON (last_week.date <@ tstzrange((this_week.rng).start, (this_week.rng).end))
              GROUP BY this_week) hrs) rep;
EOF
)
(def dollars-billed-diff-sql #<<EOF
  SELECT this_week::money, last_week::money, percentage_change(this_week, last_week)
   FROM (SELECT sum(CASE WHEN transaction_date > rng.end THEN amount ELSE 0 END) AS this_week,
                sum(CASE WHEN transaction_date <= rng.end THEN amount ELSE 0 END) AS last_week
   FROM claim_transaction two
   JOIN (SELECT (e.end - interval '1 week') AS start, e.end
         FROM (SELECT now() - interval '1 week' AS end) e) rng ON (two.transaction_date > rng.start)
    WHERE two.transaction_type_id = 4 AND two.transaction_heading = 'TPA' AND person_name(two.payee_id) ILIKE 'Maxwell%') rep ;
EOF
)


(def (sql-q con q)
  (match (sql-eval-query con q)
    ([row] row)))

(def (sql-open-diff con)
  (sql-q con open-diff-sql))

(def (sql-hours-diff con)
  (sql-q con hours-logged-diff-sql))

(def (sql-dollars-diff con)
  (sql-q con dollars-billed-diff-sql))

(def (sql-examiner-claims con)
  (let (stmt
	(sql-prepare con "SELECT * FROM examiner_open_claims_report() rep -- WHERE claim_id = 69333"))
    [(sql-columns stmt)
     (sql-query stmt) ...]))

(def (dashboard-handler req res)
  (def fn (path-strip-directory (http-request-path req)))
  (def cookies (http-request-cookies req))
  (def token (assget "ecm-login" cookies))
  (def new-claims #f)
  (def hours-logged #f)
  (def dollars-billed #f)
  (def open-claims #f)

  (displayln "Tok:" token)
  (call-with-token-connection
   token (lambda (c)
	   (displayln "conn"
		      (let (user-id (match (sql-eval-query c "SELECT login.token_user_id($1)" token)
				      ([id] id) (else #f)))
			(and user-id (get-user user-id db: c))))
	    (set! hours-logged (sql-hours-diff c))
	    (set! dollars-billed (sql-dollars-diff c))
	    (set! new-claims (sql-open-diff c))
	    (set! open-claims (sql-examiner-claims c))

	    
	    
    ))
  (cond ((equal? fn "dashboard.css")
	 (handle-dashboard.css req res))
	((equal? fn "chartScripts.js")
	 (handle-chartScripts.js req res))
	(else 
	 (let (v (call-with-output-u8vector
		  #u8() (lambda (p) (parameterize ((current-tal-output-port p))
				 (dashboard.html [["New Claims" "icon:eye" new-claims]
						  ["Hours Logged" "icon:clock" hours-logged]
						  ["Dollars Billed" "icon:credit-card" dollars-billed]
						  ]
						 open-claims)))))
	   (http-response-write res 200 `(("Content-Type" . "text/html")) v)))))
				      
(def reports-mux
  (make-static-http-mux
   (list->hash-table
    `(("/ecm/new/reports" .,(cut dashboard-handler <> <>))))
   (cut dashboard-handler <> <>)))

(def (start-reports-http-server! (address "0.0.0.0:8078"))
  (start-http-server! address mux: reports-mux))
