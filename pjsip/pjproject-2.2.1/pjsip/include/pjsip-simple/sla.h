/* $Id$ */
/* 
 * Copyright (C) 2008-2009 Teluu Inc. (http://www.teluu.com)
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

/**
 * @file sla.h
 * @brief SIP Extension for SLA (RFC 3842)
 */

#import <pjsip-simple/evsub.h>
#import <pjsip/sip_msg.h>

#define PJSIP_SLA_SUBSCRIPTION_TYPE_SLA     PJSUA_SLA_SUBSCRIPTION_TYPE_SLA
#define PJSIP_SLA_SUBSCRIPTION_TYPE_BLF     PJSUA_SLA_SUBSCRIPTION_TYPE_BLF
/**
 * @defgroup sla SIP Message Summary and Message Waiting Indication (RFC 3842)
 * @ingroup PJSIP_SIMPLE
 * @brief Support for SIP SLA Extension (RFC 3842)
 * @{
 *
 * This module implements RFC 3842: A Message Summary and Message Waiting
 * Indication Event Package for the Session Initiation Protocol (SIP).
 * It uses the SIP Event Notification framework (evsub.h) and extends the 
 * framework by implementing "message-summary" event package.
 */


/**
 * Initialize the SLA module and register it as endpoint module and
 * package to the event subscription module.
 *
 * @param endpt		The endpoint instance.
 * @param mod_evsub	The event subscription module instance.
 *
 * @return		PJ_SUCCESS if the module is successfully 
 *			initialized and registered to both endpoint
 *			and the event subscription module.
 */
PJ_DECL(pj_status_t) pjsip_sla_init_module(pjsip_endpoint *endpt,
					   pjsip_module *mod_evsub);

/**
 * Get the SLA module instance.
 *
 * @return		The SLA module instance.
 */
PJ_DECL(pjsip_module*) pjsip_sla_instance(void);

/**
 * Create SLA client subscription session.
 *
 * @param dlg		The underlying dialog to use.
 * @param user_cb	Pointer to callbacks to receive SLA subscription
 *			events.
 * @param options	Option flags. Currently only PJSIP_EVSUB_NO_EVENT_ID
 *			is recognized.
 * @param p_evsub	Pointer to receive the SLA subscription
 *			session.
 *
 * @return		PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjsip_sla_create_uac( pjsip_dialog *dlg,
					   const pjsip_evsub_user *user_cb,
					   unsigned options,
					   pjsip_evsub **p_evsub, int line, int uac_type);

/**
 * Create SLA server subscription session.
 *
 * @param dlg		The underlying dialog to use.
 * @param user_cb	Pointer to callbacks to receive SLA subscription
 *			events.
 * @param rdata		The incoming SUBSCRIBE request that creates the event 
 *			subscription.
 * @param p_evsub	Pointer to receive the SLA subscription
 *			session.
 *
 * @return		PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjsip_sla_create_uas( pjsip_dialog *dlg,
					   const pjsip_evsub_user *user_cb,
					   pjsip_rx_data *rdata,
					   pjsip_evsub **p_evsub );

/**
 * Forcefully destroy the SLA subscription. This function should only
 * be called on special condition, such as when the subscription 
 * initialization has failed. For other conditions, application MUST terminate
 * the subscription by sending the appropriate un(SUBSCRIBE) or NOTIFY.
 *
 * @param sub		The SLA subscription.
 * @param notify	Specify whether the state notification callback
 *			should be called.
 *
 * @return		PJ_SUCCESS if subscription session has been destroyed.
 */
PJ_DECL(pj_status_t) pjsip_sla_terminate( pjsip_evsub *sub,
					  pj_bool_t notify );

/**
 * Call this function to create request to initiate SLA subscription, to 
 * refresh subcription, or to request subscription termination.
 *
 * @param sub		Client subscription instance.
 * @param expires	Subscription expiration. If the value is set to zero,
 *			this will request unsubscription.
 * @param p_tdata	Pointer to receive the request.
 *
 * @return		PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjsip_sla_initiate( pjsip_evsub *sub,
					 pj_int32_t expires,
					 pjsip_tx_data **p_tdata);

/**
 * Accept the incoming subscription request by sending 2xx response to
 * incoming SUBSCRIBE request.
 *
 * @param sub		Server subscription instance.
 * @param rdata		The incoming subscription request message.
 * @param st_code	Status code, which MUST be final response.
 * @param hdr_list	Optional list of headers to be added in the response.
 *
 * @return		PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjsip_sla_accept( pjsip_evsub *sub,
				       pjsip_rx_data *rdata,
				       int st_code,
				       const pjsip_hdr *hdr_list );

/**
 * For notifier, create NOTIFY request to subscriber, and set the state 
 * of the subscription. 
 *
 * @param sub		The server subscription (notifier) instance.
 * @param state		New state to set.
 * @param state_str	The state string name, if state contains value other
 *			than active, pending, or terminated. Otherwise this
 *			argument is ignored.
 * @param reason	Specify reason if new state is terminated, otherwise
 *			put NULL.
 * @param mime_type	MIME type/content type of the message body.
 * @param body		Message body to be importd in the NOTIFY request.
 * @param p_tdata	Pointer to receive the request.
 *
 * @return		PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjsip_sla_notify( pjsip_evsub *sub,
				       pjsip_evsub_state state,
				       const pj_str_t *state_str,
				       const pj_str_t *reason,
				       const pjsip_media_type *mime_type,
				       const pj_str_t *body,
				       pjsip_tx_data **p_tdata);

/**
 * Create NOTIFY request containing message body from the last NOITFY
 * message created.
 *
 * @param sub		Server subscription object.
 * @param p_tdata	Pointer to receive request.
 *
 * @return		PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjsip_sla_current_notify( pjsip_evsub *sub,
					       pjsip_tx_data **p_tdata );


/**
 * Send request message that was previously created with initiate(), notify(),
 * or current_notify(). Application may also send request created with other
 * functions, e.g. authentication. But the request MUST be either request
 * that creates/refresh subscription or NOTIFY request.
 *
 * @param sub		The subscription object.
 * @param tdata		Request message to be sent.
 *
 * @return		PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjsip_sla_send_request( pjsip_evsub *sub,
					     pjsip_tx_data *tdata );

/**
 * @}
 */

