/* $Id$ */
/* 
 * Copyright (C) 2008-2009 Teluu Inc. (http://www.teluu.com)
 * Copyright (C) 2003-2008 Benny Prijono <benny@prijono.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
 */
#include <pjsip-simple/sla.h>
#include <pjsip-simple/errno.h>
#include <pjsip-simple/evsub_msg.h>
#include <pjsip/sip_module.h>
#include <pjsip/sip_endpoint.h>
#include <pjsip/sip_dialog.h>
#include <pjsua-lib/pjsua.h>
#include <pjsua-lib/pjsua_internal.h>
#include <pj/assert.h>
#include <pj/guid.h>
#include <pj/log.h>
#include <pj/os.h>
#include <pj/pool.h>
#include <pj/string.h>


#define THIS_FILE		    "sla.c"
#define SLA_DEFAULT_EXPIRES	    3600
#define BLF_DEFAULT_EXPIRES	    360

 /*
 * SLA module (mod-sla)
 */
static struct pjsip_module mod_sla = 
{
    NULL, NULL,			    /* prev, next.			*/
    { "mod-sla", 7 },		    /* Name.				*/
    -1,				    /* Id				*/
    PJSIP_MOD_PRIORITY_DIALOG_USAGE,/* Priority				*/
    NULL,			    /* load()				*/
    NULL,			    /* start()				*/
    NULL,			    /* stop()				*/
    NULL,			    /* unload()				*/
    NULL,			    /* on_rx_request()			*/
    NULL,			    /* on_rx_response()			*/
    NULL,			    /* on_tx_request.			*/
    NULL,			    /* on_tx_response()			*/
    NULL,			    /* on_tsx_state()			*/
};


/*
 * This structure describe an sla agent (both client and server)
 */
typedef struct pjsip_sla
{
    int                 type;    // 0:SLA     1:BLF
    int                 line;
    pjsip_evsub		*sub;		/**< Event subscribtion record.	    */
    pjsip_dialog	*dlg;		/**< The dialog.		    */
    pjsip_evsub_user	 user_cb;	/**< The user callback.		    */

    /* These are for server subscriptions */
    pj_pool_t		*body_pool;	/**< Pool to save message body	    */
    pjsip_media_type	 mime_type;	/**< MIME type of last msg body	    */
    pj_str_t		 body;		/**< Last sent message body	    */
} pjsip_sla;


/*
 * Forward decl for evsub callbacks.
 */
static void sla_on_evsub_state( pjsip_evsub *sub, pjsip_event *event);
static void sla_on_evsub_tsx_state( pjsip_evsub *sub, pjsip_transaction *tsx,
				    pjsip_event *event);
static void sla_on_evsub_rx_refresh( pjsip_evsub *sub, 
				     pjsip_rx_data *rdata,
				     int *p_st_code,
				     pj_str_t **p_st_text,
				     pjsip_hdr *res_hdr,
				     pjsip_msg_body **p_body);
static void sla_on_evsub_rx_notify( pjsip_evsub *sub, 
				    pjsip_rx_data *rdata,
				    int *p_st_code,
				    pj_str_t **p_st_text,
				    pjsip_hdr *res_hdr,
				    pjsip_msg_body **p_body);
static void sla_on_evsub_client_refresh(pjsip_evsub *sub);
static void sla_on_evsub_server_timeout(pjsip_evsub *sub);


/*
 * Event subscription callback for sla.
 */
static pjsip_evsub_user sla_user = 
{
    &sla_on_evsub_state,
    &sla_on_evsub_tsx_state,
    &sla_on_evsub_rx_refresh,
    &sla_on_evsub_rx_notify,
    &sla_on_evsub_client_refresh,
    &sla_on_evsub_server_timeout,
};


/*
 * Some static constants.
 */
static const pj_str_t STR_EVENT		 = { "Event", 5 };
static const pj_str_t STR_SLA		 = { "dialog", 6 };
static const pj_str_t STR_APP_DIALOG_XML = { "application/dialog-info+xml", 27};

/*
 * Init sla module.
 */
PJ_DEF(pj_status_t) pjsip_sla_init_module( pjsip_endpoint *endpt,
					   pjsip_module *mod_evsub)
{
    pj_status_t status;
    pj_str_t accept[1];

    /* Check arguments. */
    PJ_ASSERT_RETURN(endpt && mod_evsub, PJ_EINVAL);

    /* Must have not been registered */
    PJ_ASSERT_RETURN(mod_sla.id == -1, PJ_EINVALIDOP);

    /* Register to endpoint */
    status = pjsip_endpt_register_module(endpt, &mod_sla);
    if (status != PJ_SUCCESS)
	return status;

    accept[0] = STR_APP_DIALOG_XML;

    /* Register event package to event module. */
    status = pjsip_evsub_register_pkg( &mod_sla, &STR_SLA, 
				       SLA_DEFAULT_EXPIRES, 
				       PJ_ARRAY_SIZE(accept), accept);
    if (status != PJ_SUCCESS) {
	pjsip_endpt_unregister_module(endpt, &mod_sla);
	return status;
    }

    return PJ_SUCCESS;
}


/*
 * Get sla module instance.
 */
PJ_DEF(pjsip_module*) pjsip_sla_instance(void)
{
    return &mod_sla;
}


/*
 * Create client subscription.
 */
PJ_DEF(pj_status_t) pjsip_sla_create_uac(pjsip_dialog *dlg,
                                         const pjsip_evsub_user *user_cb,
                                         unsigned options,
                                         pjsip_evsub **p_evsub,
                                         int line, int uac_type)
{
    pj_status_t status;
    pjsip_sla *sla;
    pjsip_evsub *sub;

    PJ_ASSERT_RETURN(dlg && p_evsub, PJ_EINVAL);

    PJ_UNUSED_ARG(options);

    pjsip_dlg_inc_lock(dlg);

    /* Create event subscription */
    status = pjsip_evsub_create_uac( dlg,  &sla_user, &STR_SLA, 
				     options, &sub);
    if (status != PJ_SUCCESS)
	goto on_return;

    /* Create sla */
    sla = PJ_POOL_ZALLOC_T(dlg->pool, pjsip_sla);
    sla->dlg = dlg;
    sla->sub = sub;
    sla->line = line;
    sla->type = uac_type; 
    if (user_cb)
	pj_memcpy(&sla->user_cb, user_cb, sizeof(pjsip_evsub_user));

    /* Attach to evsub */
    pjsip_evsub_set_mod_data(sub, mod_sla.id, sla);

    *p_evsub = sub;

on_return:
    pjsip_dlg_dec_lock(dlg);
    return status;
}


/*
 * Forcefully terminate sla.
 */
PJ_DEF(pj_status_t) pjsip_sla_terminate( pjsip_evsub *sub,
					 pj_bool_t notify )
{
    return pjsip_evsub_terminate(sub, notify);
}

/*
 * Create SUBSCRIBE
 */
PJ_DEF(pj_status_t) pjsip_sla_initiate( pjsip_evsub *sub,
					pj_int32_t expires,
					pjsip_tx_data **p_tdata)
{
    return pjsip_evsub_initiate(sub, &pjsip_subscribe_method, expires, 
				p_tdata);
}

/*
 * Accept incoming subscription.
 */
PJ_DEF(pj_status_t) pjsip_sla_accept( pjsip_evsub *sub,
				      pjsip_rx_data *rdata,
				      int st_code,
				      const pjsip_hdr *hdr_list )
{
    return pjsip_evsub_accept( sub, rdata, st_code, hdr_list );
}

/*
 * Create message body and attach it to the (NOTIFY) request.
 */
static pj_status_t sla_create_msg_body( pjsip_sla *sla, 
					pjsip_tx_data *tdata)
{
	pjsip_msg_body *body;
	pj_str_t dup_text;

	PJ_ASSERT_RETURN(sla->mime_type.type.slen && sla->body.slen, PJ_EINVALIDOP);

	/* Clone the message body and mime type */
	pj_strdup(tdata->pool, &dup_text, &sla->body);

	/* Create the message body */
	body = PJ_POOL_ZALLOC_T(tdata->pool, pjsip_msg_body);
	pjsip_media_type_cp(tdata->pool, &body->content_type, &sla->mime_type);
	body->data = dup_text.ptr;
	body->len = (unsigned)dup_text.slen;
	body->print_body = &pjsip_print_text_body;
	body->clone_data = &pjsip_clone_text_data;

	/* Attach to tdata */
	tdata->msg->body = body;

	return PJ_SUCCESS;
}


/*
 * Create NOTIFY
 */
PJ_DEF(pj_status_t) pjsip_sla_notify(  pjsip_evsub *sub,
				       pjsip_evsub_state state,
				       const pj_str_t *state_str,
				       const pj_str_t *reason,
				       const pjsip_media_type *mime_type,
				       const pj_str_t *body,
				       pjsip_tx_data **p_tdata)
{
    pjsip_sla *sla;
    pjsip_tx_data *tdata;
    pj_status_t status;
    
    /* Check arguments. */
    PJ_ASSERT_RETURN(sub && mime_type && body && p_tdata, PJ_EINVAL);

    /* Get the sla object. */
    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_RETURN(sla != NULL, PJ_EINVALIDOP);

    /* Lock object. */
    pjsip_dlg_inc_lock(sla->dlg);

    /* Create the NOTIFY request. */
    status = pjsip_evsub_notify( sub, state, state_str, reason, &tdata);
    if (status != PJ_SUCCESS)
	goto on_return;

    /* Update the cached message body */
    if (mime_type || body)
	pj_pool_reset(sla->body_pool);
    if (mime_type)
	pjsip_media_type_cp(sla->body_pool, &sla->mime_type, mime_type);
    if (body)
	pj_strdup(sla->body_pool, &sla->body, body);

    /* Create message body */
    status = sla_create_msg_body( sla, tdata );
    if (status != PJ_SUCCESS)
	goto on_return;

    /* Done. */
    *p_tdata = tdata;

on_return:
    pjsip_dlg_dec_lock(sla->dlg);
    return status;
}


/*
 * Create NOTIFY that reflect current state.
 */
PJ_DEF(pj_status_t) pjsip_sla_current_notify( pjsip_evsub *sub,
					      pjsip_tx_data **p_tdata )
{
    pjsip_sla *sla;
    pjsip_tx_data *tdata;
    pj_status_t status;
    
    /* Check arguments. */
    PJ_ASSERT_RETURN(sub && p_tdata, PJ_EINVAL);

    /* Get the sla object. */
    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_RETURN(sla != NULL, PJ_EINVALIDOP);

    /* Lock object. */
    pjsip_dlg_inc_lock(sla->dlg);

    /* Create the NOTIFY request. */
    status = pjsip_evsub_current_notify( sub, &tdata);
    if (status != PJ_SUCCESS)
	goto on_return;


    /* Create message body to reflect the sla status. */
    status = sla_create_msg_body( sla, tdata );
    if (status != PJ_SUCCESS)
	goto on_return;

    /* Done. */
    *p_tdata = tdata;

on_return:
    pjsip_dlg_dec_lock(sla->dlg);
    return status;
}

/*
 * Send request.
 */
PJ_DEF(pj_status_t) pjsip_sla_send_request( pjsip_evsub *sub,
					     pjsip_tx_data *tdata )
{
    return pjsip_evsub_send_request(sub, tdata);
}

/*
 * This callback is called by event subscription when subscription
 * state has changed.
 */
static void sla_on_evsub_state( pjsip_evsub *sub, pjsip_event *event)
{
    pjsip_sla  *sla;

    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_ON_FAIL(sla!=NULL, {return;});

    if (sla->user_cb.on_evsub_state)
	(*sla->user_cb.on_evsub_state)(sub, event);

    if (pjsip_evsub_get_state(sub) == PJSIP_EVSUB_STATE_TERMINATED) {
	if (sla->body_pool) {
	    pj_pool_release(sla->body_pool);
	    sla->body_pool = NULL;
	}
    }
}

/*
 * Called when transaction state has changed.
 */
static void sla_on_evsub_tsx_state( pjsip_evsub *sub, pjsip_transaction *tsx,
				     pjsip_event *event)
{
    pjsip_sla *sla;

    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_ON_FAIL(sla!=NULL, {return;});

    if (sla->user_cb.on_tsx_state)
	(*sla->user_cb.on_tsx_state)(sub, tsx, event);
}

/*
 * Called when SUBSCRIBE is received.
 */
static void sla_on_evsub_rx_refresh( pjsip_evsub *sub, 
				     pjsip_rx_data *rdata,
				     int *p_st_code,
				     pj_str_t **p_st_text,
				     pjsip_hdr *res_hdr,
				     pjsip_msg_body **p_body)
{
    pjsip_sla *sla;

    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_ON_FAIL(sla!=NULL, {return;});

    if (sla->user_cb.on_rx_refresh) {
	(*sla->user_cb.on_rx_refresh)(sub, rdata, p_st_code, p_st_text,
				       res_hdr, p_body);

    } else {
	/* Implementors MUST send NOTIFY if it implements on_rx_refresh */
	pjsip_tx_data *tdata;
	pj_str_t timeout = { "timeout", 7};
	pj_status_t status;

	if (pjsip_evsub_get_state(sub)==PJSIP_EVSUB_STATE_TERMINATED) {
	    status = pjsip_sla_notify( sub, PJSIP_EVSUB_STATE_TERMINATED,
				       NULL, &timeout, NULL, NULL, &tdata);
	} else {
	    status = pjsip_sla_current_notify(sub, &tdata);
	}

	if (status == PJ_SUCCESS)
	    pjsip_sla_send_request(sub, tdata);
    }
}

/*
 * Called when NOTIFY is received.
 */
static void sla_on_evsub_rx_notify( pjsip_evsub *sub, 
				     pjsip_rx_data *rdata,
				     int *p_st_code,
				     pj_str_t **p_st_text,
				     pjsip_hdr *res_hdr,
				     pjsip_msg_body **p_body)
{
    pjsip_sla *sla;

    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_ON_FAIL(sla!=NULL, {return;});

    /* Just notify application. */
    if (sla->user_cb.on_rx_notify) {
	(*sla->user_cb.on_rx_notify)(sub, rdata, p_st_code, p_st_text, 
				     res_hdr, p_body);
    }
}



/*
 * Called when it's time to send SUBSCRIBE.
 */
static void sla_on_evsub_client_refresh(pjsip_evsub *sub)
{
    pjsip_sla *sla;

    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_ON_FAIL(sla!=NULL, {return;});

    if (sla->user_cb.on_client_refresh) {
	(*sla->user_cb.on_client_refresh)(sub);
    } else {
	pj_status_t status;
	pjsip_tx_data *tdata;

        if(sla->type == PJSIP_SLA_SUBSCRIPTION_TYPE_BLF)
        {
	    status = pjsip_sla_initiate(sub, BLF_DEFAULT_EXPIRES, &tdata);
        }
        else
        {
	    status = pjsip_sla_initiate(sub, -1, &tdata);
        }
	if (status == PJ_SUCCESS)
	    pjsip_sla_send_request(sub, tdata);
    }
}

/*
 * Called when no refresh is received after the interval.
 */
static void sla_on_evsub_server_timeout(pjsip_evsub *sub)
{
    pjsip_sla *sla;

    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_ON_FAIL(sla!=NULL, {return;});

    if (sla->user_cb.on_server_timeout) {
	(*sla->user_cb.on_server_timeout)(sub);
    } else {
	pj_status_t status;
	pjsip_tx_data *tdata;
	pj_str_t reason = { "timeout", 7 };

	status = pjsip_sla_notify(sub, PJSIP_EVSUB_STATE_TERMINATED,
				   NULL, &reason, NULL, NULL, &tdata);
	if (status == PJ_SUCCESS)
	    pjsip_sla_send_request(sub, tdata);
    }
}

/***************************************************************************
 * Shared Line Appearance
 */
/* Callback called when *client* subscription state has changed. */
static void sla_evsub_on_state( pjsip_evsub *sub, pjsip_event *event)
{
    pjsua_acc *acc;
    pjsip_sla *sla;	
    int setModData = 1, i;
	
    PJ_UNUSED_ARG(event);
	
    /* Note: #937: no need to acuire PJSUA_LOCK here. Since the buddy has
     *   a dialog attached to it, lock_buddy() will use the dialog
     *   lock, which we are currently holding!
     */
    acc = (pjsua_acc*) pjsip_evsub_get_mod_data(sub, pjsua_var.mod.id);
    if (!acc)
		return;	
	
    sla = (pjsip_sla*) pjsip_evsub_get_mod_data(sub, mod_sla.id);
    PJ_ASSERT_ON_FAIL(sla!=NULL, {return;});
	
    if(sla->type == PJSIP_SLA_SUBSCRIPTION_TYPE_SLA)
    {
         PJ_LOG(4,(THIS_FILE, 
			  "SLA line%d subscription for %.*s is %s",sla->line,
			  (int)acc->cfg.id.slen, acc->cfg.id.ptr, 
			  pjsip_evsub_get_state_name(sub)));
    }
    else
    {
         PJ_LOG(4,(THIS_FILE, 
			  "BLF %.*s subscription for %.*s is %s",
			  (int)acc->cfg.blf[sla->line].slen, acc->cfg.blf[sla->line].ptr, 
			  (int)acc->cfg.id.slen, acc->cfg.id.ptr, 
			  pjsip_evsub_get_state_name(sub)));
    }
	
    if (pjsip_evsub_get_state(sub) == PJSIP_EVSUB_STATE_TERMINATED) {
	pjsua_sla_info sla_info;
	/* Call callback */
	if (pjsua_var.ua_cfg.cb.on_sla_info) {
		sla_info.evsub = sub;
		sla_info.rdata = NULL;
		sla_info.line  = sla->line;
                sla_info.type  = sla->type;
		(*pjsua_var.ua_cfg.cb.on_sla_info)(acc->index, &sla_info);
	}		

        if(sla->type == PJSIP_SLA_SUBSCRIPTION_TYPE_SLA)
        {
            if(sla->line >= 1 && sla->line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
            {
                acc->sla_line_dlg[sla->line] = NULL;
                acc->sla_line_sub[sla->line] = NULL;
            }

    	    for(i = 1; i < PJSUA_MAX_NUMBER_OF_SHARED_LINES; i++)
            {
                if(acc->sla_line_dlg[i] != NULL)
                {
                    setModData = 0;
                    break;
                }
            }
        }
        else // BLF
        {
            if(sla->line >= 0 && sla->line < PJSUA_MAX_NUMBER_OF_BLF_DEVICES)
            {
                acc->blf_line_dlg[sla->line] = NULL;
                acc->blf_line_sub[sla->line] = NULL;
            }

    	    for(i = 0; i < PJSUA_MAX_NUMBER_OF_BLF_DEVICES; i++)
            {
                if(acc->blf_line_dlg[i] != NULL)
                {
                    setModData = 0;
                    break;
                }
            }
        }

        if(setModData)
        {
            pjsip_evsub_set_mod_data(sub, pjsua_var.mod.id, NULL); 
        }
    }
}

/* Callback called when we receive NOTIFY */
static void sla_evsub_on_rx_notify(pjsip_evsub *sub, 
								   pjsip_rx_data *rdata,
								   int *p_st_code,
								   pj_str_t **p_st_text,
								   pjsip_hdr *res_hdr,
								   pjsip_msg_body **p_body)
{
    pjsua_sla_info sla_info;
    pjsua_acc *acc;
	
    PJ_UNUSED_ARG(p_st_code);
    PJ_UNUSED_ARG(p_st_text);
    PJ_UNUSED_ARG(res_hdr);
    PJ_UNUSED_ARG(p_body);
	
    acc = (pjsua_acc*) pjsip_evsub_get_mod_data(sub, pjsua_var.mod.id);
    if (!acc)
		return;
	
    /* Construct sla_info */
    pj_bzero(&sla_info, sizeof(sla_info));
    sla_info.evsub = sub;
    sla_info.rdata = rdata;
	
    /* Call callback */
    if (pjsua_var.ua_cfg.cb.on_sla_info) {
		(*pjsua_var.ua_cfg.cb.on_sla_info)(acc->index, &sla_info);
    }
}


/* Event subscription callback. */
static pjsip_evsub_user sla_cb = 
{
    &sla_evsub_on_state,  
    NULL,   /* on_tsx_state: not interested */
    NULL,   /* on_rx_refresh: don't care about SUBSCRIBE refresh, unless 
			 * we want to authenticate 
			 */
	
    &sla_evsub_on_rx_notify,
	
    NULL,   /* on_client_refresh: Use default behaviour, which is to 
			 * refresh client subscription. */
	
    NULL,   /* on_server_timeout: Use default behaviour, which is to send 
			 * NOTIFY to terminate. 
			 */
};

void pjsua_start_sla(pjsua_acc *acc, int line)
{
    pj_pool_t         *tmp_pool = NULL;
    pj_str_t          contact;
    pjsip_tx_data     *tdata;
    pj_status_t       status;
	pj_bool_t         sla_enabled;
	pjsip_evsub	      **sla_sub;	    
    pjsip_dialog      **sla_dlg;
	pj_str_t          *remote;
	
    if(line >= 1 && line < PJSUA_MAX_NUMBER_OF_SHARED_LINES)
    {
        sla_enabled = acc->cfg.sla_line_enabled[line];
        sla_sub     = &acc->sla_line_sub[line];
        sla_dlg     = &acc->sla_line_dlg[line];
        remote      = &acc->cfg.line[line];  
    }
    else
    {
        return;
    }
	
	PJ_LOG(4,(THIS_FILE, "SLA Subscribe Local %s",acc->cfg.id.ptr));
	PJ_LOG(4,(THIS_FILE, "SLA Subscribe Remote %s",remote->ptr));
	if (!sla_enabled) {
		if (*sla_sub) {
			/* Terminate SLA subscription */
			pjsip_tx_data *tdata;
			pjsip_evsub *sub = *sla_sub;
			
			/* Detach sub from this account */
			*sla_sub = NULL;
			*sla_dlg = NULL;
			pjsip_evsub_set_mod_data(sub, pjsua_var.mod.id, NULL);
			
			/* Unsubscribe */
			status = pjsip_sla_initiate(*sla_sub, 0, &tdata);
			if (status == PJ_SUCCESS) {
				status = pjsip_sla_send_request(*sla_sub, tdata);
			}
		}
		return;
    }
	
    if (*sla_sub) {
		/* Subscription is already active */
		return;
		
    }
	
    /* Generate suitable Contact header unless one is already set in 
     * the account
     */
    if (acc->contact.slen) {
		contact = acc->contact;
    } else {
		tmp_pool = pjsua_pool_create("tmpsla", 512, 256);
		status = pjsua_acc_create_uac_contact(tmp_pool, &contact,
											  acc->index, &acc->cfg.id);
		if (status != PJ_SUCCESS) {
			pjsua_perror(THIS_FILE, "Unable to generate Contact header", 
						 status);
			pj_pool_release(tmp_pool);
			return;
		}
    }
	
    /* Create UAC dialog */
    status = pjsip_dlg_create_uac( pjsip_ua_instance(),
								  &acc->cfg.id,
								  &contact,
								  remote,
								  NULL, sla_dlg);
    if (status != PJ_SUCCESS) {
		pjsua_perror(THIS_FILE, "Unable to create dialog", status);
		if (tmp_pool) pj_pool_release(tmp_pool);
		return;
    }
	
    /* Increment the dialog's lock otherwise when presence session creation
     * fails the dialog will be destroyed prematurely.
     */
    pjsip_dlg_inc_lock(*sla_dlg);
	
    /* Create UAC subscription */
    status = pjsip_sla_create_uac(*sla_dlg, &sla_cb, 
								  PJSIP_EVSUB_NO_EVENT_ID, sla_sub, line, PJSIP_SLA_SUBSCRIPTION_TYPE_SLA);
    if (status != PJ_SUCCESS) {
		pjsua_perror(THIS_FILE, "Error creating SLA subscription", status);
		if (tmp_pool) pj_pool_release(tmp_pool);
		if (*sla_dlg) pjsip_dlg_dec_lock(*sla_dlg);
		return;
    }
	
    /* If account is locked to specific transport, then lock dialog
     * to this transport too.
     */
    if (acc->cfg.transport_id != PJSUA_INVALID_ID) {
		pjsip_tpselector tp_sel;
		
		pjsua_init_tpselector(acc->cfg.transport_id, &tp_sel);
		pjsip_dlg_set_transport(*sla_dlg, &tp_sel);
    }
	
    /* Set route-set */
    if (!pj_list_empty(&acc->route_set)) {
		pjsip_dlg_set_route_set(*sla_dlg, &acc->route_set);
    }
	
    /* Set credentials */
    if (acc->cred_cnt) {
		pjsip_auth_clt_set_credentials( &(*sla_dlg)->auth_sess, 
									   acc->cred_cnt, acc->cred);
    }
	
    /* Set authentication preference */
    pjsip_auth_clt_set_prefs(&(*sla_dlg)->auth_sess, &acc->cfg.auth_pref);
	
    pjsip_evsub_set_mod_data(*sla_sub, pjsua_var.mod.id, acc);
	
    status = pjsip_sla_initiate(*sla_sub, -1, &tdata);
    if (status != PJ_SUCCESS) {
		if (*sla_dlg) pjsip_dlg_dec_lock(*sla_dlg);
		if (*sla_sub) {
			pjsip_pres_terminate(*sla_sub, PJ_FALSE);
		}
		*sla_sub = NULL;
		*sla_dlg = NULL;
		pjsua_perror(THIS_FILE, "Unable to create initial SLA SUBSCRIBE", 
					 status);
		if (tmp_pool) pj_pool_release(tmp_pool);
		return;
    }
	
    pjsua_process_msg_data(tdata, NULL);
    status = pjsip_pres_send_request(*sla_sub, tdata);
    if (status != PJ_SUCCESS) {
		if (*sla_dlg) pjsip_dlg_dec_lock(*sla_dlg);
		if (*sla_sub) {
			pjsip_pres_terminate(*sla_sub, PJ_FALSE);
		}
		*sla_sub = NULL;
		*sla_dlg = NULL;
		pjsua_perror(THIS_FILE, "Unable to send initial SLA SUBSCRIBE", 
					 status);
		if (tmp_pool) pj_pool_release(tmp_pool);
		return;
    }
	
    pjsip_dlg_dec_lock(*sla_dlg);
    if (tmp_pool) pj_pool_release(tmp_pool);
	
}


/***************************************************************************
 * Unsolicited SLA
 */
static pj_bool_t unsolicited_sla_on_rx_request(pjsip_rx_data *rdata)
{
    pjsip_msg *msg = rdata->msg_info.msg;
    pj_str_t EVENT_HDR  = { "Event", 5 };
    pj_str_t SLA = { "dialog", 6 };
    pjsip_event_hdr *eh;
	
    if (pjsip_method_cmp(&msg->line.req.method, &pjsip_notify_method)!=0) {
		/* Only interested with NOTIFY request */
		return PJ_FALSE;
    }
	
    eh = (pjsip_event_hdr*) pjsip_msg_find_hdr_by_name(msg, &EVENT_HDR, NULL);
    if (!eh) {
		/* Something wrong with the request, it has no Event hdr */
		return PJ_FALSE;
    }
	
    if (pj_stricmp(&eh->event_type, &SLA) != 0) {
		/* Not SLA event */
		return PJ_FALSE;
    }
	
    /* Got unsolicited SLA request, respond with 200/OK first */
    pjsip_endpt_respond(pjsua_get_pjsip_endpt(), NULL, rdata, 200, NULL,
						NULL, NULL, NULL);
	
	
    /* Call callback */
    if (pjsua_var.ua_cfg.cb.on_sla_info) {
		pjsua_acc_id acc_id;
		pjsua_sla_info sla_info;
		
		acc_id = pjsua_acc_find_for_incoming(rdata);
		
		pj_bzero(&sla_info, sizeof(sla_info));
		sla_info.rdata = rdata;
		
		(*pjsua_var.ua_cfg.cb.on_sla_info)(acc_id, &sla_info);
    }
	
    
    return PJ_TRUE;
}

/* The module instance. */
static pjsip_module pjsua_unsolicited_sla_mod = 
{
    NULL, NULL,				/* prev, next.		*/
    { "mod-unsolicited-sla", 19 },	/* Name.		*/
    -1,					/* Id			*/
    PJSIP_MOD_PRIORITY_APPLICATION,	/* Priority	        */
    NULL,				/* load()		*/
    NULL,				/* start()		*/
    NULL,				/* stop()		*/
    NULL,				/* unload()		*/
    &unsolicited_sla_on_rx_request,	/* on_rx_request()	*/
    NULL,				/* on_rx_response()	*/
    NULL,				/* on_tx_request.	*/
    NULL,				/* on_tx_response()	*/
    NULL,				/* on_tsx_state()	*/
};

static pj_status_t enable_unsolicited_sla(void)
{
    pj_status_t status;
	
    status = pjsip_endpt_register_module(pjsua_get_pjsip_endpt(), 
										 &pjsua_unsolicited_sla_mod);
    if (status != PJ_SUCCESS)
		pjsua_perror(THIS_FILE, "Error registering unsolicited SLA module", 
					 status);
	
    return status;
}

/* BLF  */
void pjsua_start_blf(pjsua_acc *acc, int line)
{
    pj_pool_t         *tmp_pool = NULL;
    pj_str_t          contact;
    pjsip_tx_data     *tdata;
    pj_status_t       status;
    pj_bool_t         sla_enabled;
    pjsip_evsub           **sla_sub;
    pjsip_dialog      **sla_dlg;
    pj_str_t          *remote;

    if(line >= 0 && line < PJSUA_MAX_NUMBER_OF_BLF_DEVICES)
    {
        sla_enabled = acc->cfg.blf_enabled[line];
        sla_sub     = &acc->blf_line_sub[line];
        sla_dlg     = &acc->blf_line_dlg[line];
        remote      = &acc->cfg.blf[line];
    }
    else
    {
        return;
    }

    PJ_LOG(4,(THIS_FILE, "BLF Subscribe Local %s",acc->cfg.id.ptr));
    PJ_LOG(4,(THIS_FILE, "BLF Subscribe Remote %s",remote->ptr));
    if (!sla_enabled) {
       if (*sla_sub) {
          /* Terminate SLA subscription */
          pjsip_tx_data *tdata;
          pjsip_evsub *sub = *sla_sub;

          /* Detach sub from this account */
           *sla_sub = NULL;
           *sla_dlg = NULL;
           pjsip_evsub_set_mod_data(sub, pjsua_var.mod.id, NULL);

          /* Unsubscribe */
           status = pjsip_sla_initiate(sub, 0, &tdata);
           if (status == PJ_SUCCESS) {
              status = pjsip_sla_send_request(sub, tdata);
           }
        }
        return;
    }

    if (*sla_sub) {
       /* Subscription is already active */
       PJ_LOG(4,(THIS_FILE, "BLF Subscription is already active"));
       return;
    }

    /* Generate suitable Contact header unless one is already set in
     * the account
     */
    if (acc->contact.slen) {
                contact = acc->contact;
    } else {
           tmp_pool = pjsua_pool_create("tmpsla", 512, 256);
           status = pjsua_acc_create_uac_contact(tmp_pool, &contact,
                                                      acc->index, &acc->cfg.id);
           if (status != PJ_SUCCESS) {
              pjsua_perror(THIS_FILE, "Unable to generate Contact header", status);
              pj_pool_release(tmp_pool);
              return;
           }
    }

    /* Create UAC dialog */
    status = pjsip_dlg_create_uac( pjsip_ua_instance(),
                               &acc->cfg.id,
                               &contact,
                               remote,
                               NULL, sla_dlg);
    if (status != PJ_SUCCESS) {
        pjsua_perror(THIS_FILE, "Unable to create dialog", status);
        if (tmp_pool) pj_pool_release(tmp_pool);
        return;
    }

    /* Increment the dialog's lock otherwise when presence session creation
     * fails the dialog will be destroyed prematurely.
     */
    pjsip_dlg_inc_lock(*sla_dlg);


    /* Create UAC subscription */
    status = pjsip_sla_create_uac(*sla_dlg, &sla_cb, PJSIP_EVSUB_NO_EVENT_ID, sla_sub, line, PJSIP_SLA_SUBSCRIPTION_TYPE_BLF);
    if (status != PJ_SUCCESS) {
                pjsua_perror(THIS_FILE, "Error creating BLF subscription", status);
                if (tmp_pool) pj_pool_release(tmp_pool);
                if (*sla_dlg) pjsip_dlg_dec_lock(*sla_dlg);
                return;
    }

    /* If account is locked to specific transport, then lock dialog
     * to this transport too.
     */
    if (acc->cfg.transport_id != PJSUA_INVALID_ID) {
                pjsip_tpselector tp_sel;

                pjsua_init_tpselector(acc->cfg.transport_id, &tp_sel);
                pjsip_dlg_set_transport(*sla_dlg, &tp_sel);
    }

    /* Set route-set */
    if (!pj_list_empty(&acc->route_set)) {
                pjsip_dlg_set_route_set(*sla_dlg, &acc->route_set);
    }

    /* Set credentials */
    if (acc->cred_cnt) {
                pjsip_auth_clt_set_credentials( &(*sla_dlg)->auth_sess,
                                                                           acc->cred_cnt, acc->cred);
    }

    /* Set authentication preference */
    pjsip_auth_clt_set_prefs(&(*sla_dlg)->auth_sess, &acc->cfg.auth_pref);

    pjsip_evsub_set_mod_data(*sla_sub, pjsua_var.mod.id, acc);

    status = pjsip_sla_initiate(*sla_sub, BLF_DEFAULT_EXPIRES, &tdata);
    if (status != PJ_SUCCESS) {
                if (*sla_dlg) pjsip_dlg_dec_lock(*sla_dlg);
                if (*sla_sub) {
                        pjsip_pres_terminate(*sla_sub, PJ_FALSE);
                }
                *sla_sub = NULL;
                *sla_dlg = NULL;
                pjsua_perror(THIS_FILE, "Unable to create initial BLF SUBSCRIBE",
                                         status);
                if (tmp_pool) pj_pool_release(tmp_pool);
                return;
    }

    pjsua_process_msg_data(tdata, NULL);
    status = pjsip_pres_send_request(*sla_sub, tdata);
    if (status != PJ_SUCCESS) {
                if (*sla_dlg) pjsip_dlg_dec_lock(*sla_dlg);
                if (*sla_sub) {
                        pjsip_pres_terminate(*sla_sub, PJ_FALSE);
                }
                *sla_sub = NULL;
                *sla_dlg = NULL;
                pjsua_perror(THIS_FILE, "Unable to send initial BLF SUBSCRIBE",
                                         status);
                if (tmp_pool) pj_pool_release(tmp_pool);
                return;
    }

    pjsip_dlg_dec_lock(*sla_dlg);
    if (tmp_pool) pj_pool_release(tmp_pool);

}
