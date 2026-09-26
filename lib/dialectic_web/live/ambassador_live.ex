defmodule DialecticWeb.AmbassadorLive do
  use DialecticWeb, :live_view

  alias Dialectic.Ambassadors

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "The Ambassador Programme — RationalGrid",
       page_title_suffix: "",
       page_description:
         "See how students use AI through shared grids. Organise learning, guide questions, and help students build understanding with RationalGrid’s proposed ambassador programme.",
       form: to_form(Ambassadors.change_interest(), as: :interest),
       joined?: false,
       signup_available?: Ambassadors.configured?(),
       submission_error: nil
     ), layout: false}
  end

  @impl true
  def handle_event("select-student", _params, socket) do
    form =
      socket.assigns.form.params
      |> Map.put("role", "student")
      |> Ambassadors.change_interest()
      |> to_form(as: :interest)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("validate", %{"interest" => params}, socket) do
    form =
      params
      |> Ambassadors.change_interest()
      |> Map.put(:action, :validate)
      |> to_form(as: :interest)

    {:noreply, assign(socket, form: form, submission_error: nil)}
  end

  def handle_event("join", _params, %{assigns: %{joined?: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("join", %{"interest" => params}, socket) do
    save_interest(socket, params)
  end

  defp save_interest(socket, params) do
    socket = assign(socket, :form, to_form(Ambassadors.change_interest(params), as: :interest))

    case Ambassadors.register_interest(params) do
      {:ok, _interest} ->
        {:noreply, assign(socket, joined?: true, submission_error: nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :interest))}

      {:error, :not_configured} ->
        {:noreply,
         assign(socket, :submission_error, "Registration opens soon. Please check back shortly.")}

      {:error, _reason} ->
        {:noreply,
         assign(
           socket,
           :submission_error,
           "We couldn’t save your details. Please try again shortly."
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="ambassador-page" class="ambassador-page">
        <header class="amb-nav">
          <a id="ambassador-home-link" href={~p"/"} class="amb-brand" aria-label="RationalGrid home">
            <span class="amb-brand-icon">
              <img
                id="ambassador-logo"
                src={~p"/images/brandmark.svg"}
                alt=""
                width="24"
                height="24"
                class="h-6 w-6"
              />
            </span>
            RationalGrid<span class="amb-brand-dot">.</span>
          </a>
          <nav aria-label="Ambassador programme" class="amb-nav-links">
            <a id="amb-how-link" href="#how-it-works" class="amb-nav-secondary">How it works</a>
            <a id="amb-earn-link" href="#how-you-earn" class="amb-nav-secondary">How you earn</a>
            <a id="amb-benefits-link" href="#why-join" class="amb-nav-secondary">Why join?</a>
            <a id="amb-faq-link" href="#ambassador-faq" class="amb-nav-secondary">FAQs</a>
            <a id="amb-nav-join" href="#join-programme" class="amb-button amb-button-small">
              Register your interest <.icon name="hero-arrow-up-right" class="h-4 w-4" />
            </a>
          </nav>
        </header>

        <section id="ambassador-hero" class="amb-hero amb-container" aria-labelledby="amb-hero-title">
          <div class="amb-hero-copy">
            <p class="amb-eyebrow"><span class="amb-status-dot"></span> THE AMBASSADOR PROGRAMME</p>
            <h1 id="amb-hero-title">We’re RationalGrid.<br />Teach. Guide. <em>Earn.</em></h1>
            <p id="amb-hero-description" class="amb-hero-description">
              An AI learning workspace for your students—and a view of the work they share.
              See what they ask, guide their next questions, and help their learning last.
              Our proposed programme adds branded hubs and a share of eligible subscription revenue.
            </p>
            <div class="amb-hero-actions">
              <a id="amb-hero-join" href="#join-programme" class="amb-button">
                Register your interest <.icon name="hero-arrow-up-right" class="h-4 w-4" />
              </a>
              <a id="amb-hero-product" href={~p"/"} class="amb-button amb-button-product">
                Explore RationalGrid <.icon name="hero-arrow-up-right" class="h-4 w-4" />
              </a>
            </div>
            <p class="amb-hero-note">
              <.icon name="hero-check-circle" class="h-4 w-4" />
              Try RationalGrid today. Help shape the ambassador programme before launch.
            </p>
          </div>

          <div
            id="ambassador-hub-preview"
            role="img"
            class="amb-hero-visual"
            aria-label="Illustrative preview of an educator’s branded learning hub"
          >
            <div class="amb-visual-orbit amb-orbit-one"></div>
            <div class="amb-visual-orbit amb-orbit-two"></div>
            <span class="amb-visual-star" aria-hidden="true">✳</span>
            <div class="amb-hub">
              <div class="amb-hub-browser">
                <span class="amb-browser-dots" aria-hidden="true"><i></i><i></i><i></i></span>
                <span><.icon name="hero-lock-closed" class="h-3 w-3" /> your learning space</span>
                <.icon name="hero-ellipsis-horizontal" class="h-4 w-4" />
              </div>
              <div class="amb-hub-header">
                <span class="amb-hub-monogram">JL</span>
                <div>
                  <strong>Jamie’s Learning Studio</strong><span>Powered by RationalGrid</span>
                </div>
                <span class="amb-hub-avatar">J</span>
              </div>
              <div class="amb-hub-content">
                <p class="amb-hub-kicker">KEEP LEARNING BETWEEN LESSONS</p>
                <h2>Revisit an idea.<br />Take it further.</h2>
                <p>Recall an idea. Check it. Share your next question.</p>
                <div class="amb-hub-tabs">
                  <span>My Learning</span><span>Topics</span><span>Collections</span>
                </div>
                <div class="amb-lesson">
                  <span class="amb-lesson-icon"><.icon name="hero-light-bulb" class="h-5 w-5" /></span>
                  <div>
                    <span>BEFORE OUR NEXT LESSON</span><strong>What makes a source trustworthy?</strong>
                  </div>
                  <.icon name="hero-arrow-up-right" class="h-4 w-4" />
                </div>
                <div class="amb-reasoning-path" aria-hidden="true"><span></span><span></span></div>
                <div class="amb-hub-topics">
                  <div>
                    <.icon name="hero-magnifying-glass" class="h-4 w-4" /><strong>Revisit the evidence</strong><span>Explain it in your own words</span>
                  </div>
                  <div>
                    <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" /><strong>Bring back a question</strong><span>Where do you need guidance?</span>
                  </div>
                </div>
              </div>
              <div class="amb-hub-footer">
                <span class="amb-status-dot"></span> Guided by an educator. Powered by curiosity.
              </div>
            </div>
            <div class="amb-float amb-float-brand">
              <span><.icon name="hero-swatch" class="h-5 w-5" /></span><div>
                <strong>Your brand. Your space.</strong><small>A hub that feels like you.</small>
              </div>
            </div>
            <div class="amb-float amb-float-earn">
              <span><.icon name="hero-arrow-trending-up" class="h-5 w-5" /></span><div>
                <strong>Teach. Inspire. Earn.</strong><small>Grow together, share the rewards.</small>
              </div>
            </div>
            <p class="amb-preview-label">
              A little glimpse of what we’re building. Illustrative preview.
            </p>
          </div>
        </section>

        <section class="amb-audience" aria-label="Who the programme is for">
          <div class="amb-container amb-audience-inner">
            <span>FOR THE PEOPLE WHO<br /><strong>MAKE LEARNING HAPPEN.</strong></span>
            <p><.icon name="hero-academic-cap" class="h-6 w-6" /> Educators</p>
            <p><.icon name="hero-chat-bubble-left-right" class="h-6 w-6" /> Independent tutors</p>
            <p><.icon name="hero-building-library" class="h-6 w-6" /> Schools & institutions</p>
            <p><.icon name="hero-user-group" class="h-6 w-6" /> Learning communities</p>
          </div>
        </section>

        <section id="how-it-works" class="amb-section amb-container" aria-labelledby="amb-how-title">
          <div class="amb-section-heading">
            <div>
              <p class="amb-eyebrow">A SHARED MISSION. A SHARED OPPORTUNITY.</p><h2 id="amb-how-title">
                Your subject. Your students. Your guidance.
              </h2>
            </div>
            <p>
              Start with what you teach. Give students a reason to return.<br />Here’s how the proposed programme would work.
            </p>
          </div>
          <div class="amb-steps">
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-peach"><.icon name="hero-window" class="h-6 w-6" /></span><span>01 / MAKE IT YOURS</span>
              </div><h3>Bring students into your hub</h3><p>
                Invite students to your proposed branded hub. Start with a question from your
                subject and explore it in shared grids.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-green"><.icon
                  name="hero-sparkles"
                  class="h-6 w-6"
                /></span><span>02 / GUIDE THE CURIOSITY</span>
              </div><h3>Make the learning visible</h3><p>
                Ask students to share their grids. See who asked what, review the AI responses,
                and plan your next lesson around the gaps.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-purple"><.icon
                  name="hero-arrow-trending-up"
                  class="h-6 w-6"
                /></span><span>03 / SHARE IN THE GROWTH</span>
              </div><h3>Share in subscription revenue</h3><p>
                Under the proposed model, you would earn a share when a student you introduce
                takes an eligible paid subscription.
              </p>
            </article>
          </div>
          <p class="amb-terms-note">
            We’re gathering early interest. Hub features, revenue share, and programme terms will be confirmed before launch.
          </p>
        </section>

        <section id="why-join" class="amb-mission amb-container" aria-labelledby="amb-mission-title">
          <div class="amb-mission-art" aria-hidden="true">
            <span class="amb-art-word">human</span>
            <span class="amb-art-plus">+</span>
            <span class="amb-art-ai">AI<span>✳</span></span>
            <span class="amb-art-caption">BETTER, TOGETHER.</span>
          </div>
          <div class="amb-mission-copy">
            <p class="amb-eyebrow">GUIDE STUDENT AI USE</p>
            <h2 id="amb-mission-title">
              See how students use AI.<br /><em>Guide what happens next.</em>
            </h2>
            <p id="amb-student-visibility">
              Students are already using AI. Ask them to share their grids so you can see their
              questions and exploration, instead of guessing from the final assignment.
            </p>
            <ul>
              <li id="amb-student-questions">
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>See who asked what.</strong>
                Follow signed-in students’ questions and AI responses in shared grids.
                Ask them to explain their choices and use that discussion to guide feedback.</span>
              </li>
              <li id="amb-student-organisation">
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>Keep a class’s work together.</strong>
                In My Learning, Topics start from grid tags. Create your own Collections to group
                shared grids by class, project, or subject.</span>
              </li>
              <li id="amb-shared-learning">
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>Learn with each other.</strong>
                Compare perspectives, add questions to shared grids, and build on each other’s ideas.</span>
              </li>
              <li id="amb-lasting-learning">
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>Make learning last.</strong>
                Save useful passages with bookmarks and highlights. Recall strengthens memory;
                connecting ideas deepens understanding.</span>
              </li>
            </ul>
            <a id="amb-mission-join" href="#join-programme" class="amb-text-link">Help shape what comes next
            <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
          </div>
        </section>

        <section id="how-you-earn" class="amb-section amb-container" aria-labelledby="amb-earn-title">
          <div class="amb-section-heading">
            <div>
              <p class="amb-eyebrow">THE PROPOSED REVENUE-SHARING MODEL</p>
              <h2 id="amb-earn-title">You bring the learners.<br />You share in the revenue.</h2>
            </div>
            <p>
              A share of eligible paid subscriptions from students you introduce.<br />Here’s what that could look like for a tutor.
            </p>
          </div>
          <div class="amb-steps">
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-peach"><.icon
                  name="hero-user-plus"
                  class="h-6 w-6"
                /></span>
                <span>01 / YOU INTRODUCE</span>
              </div>
              <h3>Invite your teaching group</h3>
              <p>
                Imagine you tutor biology. You introduce your students to your RationalGrid hub
                and use a question from this week’s lesson to get them exploring.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-green"><.icon
                  name="hero-book-open"
                  class="h-6 w-6"
                /></span>
                <span>02 / THEY SUBSCRIBE</span>
              </div>
              <h3>Students choose to continue</h3>
              <p>
                They revisit explanations, question the evidence, and prepare for your next
                lesson. If they choose an eligible paid subscription through your hub, that
                subscription would count towards your revenue share.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-purple"><.icon
                  name="hero-arrow-trending-up"
                  class="h-6 w-6"
                /></span>
                <span>03 / YOU EARN</span>
              </div>
              <h3>Receive your agreed share</h3>
              <p>
                You would earn a percentage of qualifying subscription revenue under the
                programme’s agreed terms. The opportunity grows with the students who find
                continuing value in the learning you guide.
              </p>
            </article>
          </div>
          <p class="amb-terms-note">
            Illustrative example of the proposed programme. Rates, eligible subscriptions,
            referral attribution, payment schedules, and how long revenue sharing lasts will be
            confirmed before you join. Registering interest does not start an earning arrangement.
          </p>
        </section>

        <section
          id="student-referrals"
          class="amb-referral amb-container"
          aria-labelledby="amb-referral-title"
        >
          <span class="amb-referral-icon"><.icon name="hero-users" class="h-7 w-7" /></span>
          <div>
            <p class="amb-eyebrow">GOOD IDEAS TRAVEL.</p><h2 id="amb-referral-title">
              A student? Bring a friend. Share the upside.
            </h2><p>
              We’re exploring peer referrals too: introduce a friend who takes an eligible paid
              subscription and receive a share of those fees under the programme’s terms.
              Register as a student for updates on this proposed opportunity.
            </p>
          </div>
          <a
            id="amb-student-join"
            href="#join-programme"
            class="amb-text-link"
            phx-click="select-student"
          >Register as a student <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
        </section>

        <section id="join-programme" class="amb-join amb-container" aria-labelledby="amb-join-title">
          <div class="amb-join-copy">
            <p class="amb-eyebrow">BE PART OF THE NEXT CHAPTER</p><h2 id="amb-join-title">
              Take your teaching further.<br /><em>Help shape the programme.</em>
            </h2><p>
              Help shape a hub for guiding student AI use, organising learning, and sharing in
              eligible subscription revenue. Register for updates and early-access opportunities.
            </p><span><.icon name="hero-arrow-up-right" class="h-5 w-5" /> Early interest is now open</span>
          </div>
          <div class="amb-signup-card">
            <div
              :if={@joined?}
              id="ambassador-success"
              class="amb-success"
              role="status"
              aria-live="polite"
            >
              <span class="amb-success-icon"><.icon name="hero-check" class="h-7 w-7" /></span>
              <h3>You’re on the list.</h3>
              <p>
                Thanks for helping shape what comes next. We’ve saved your interest and will be in touch with programme updates and early-access opportunities.
              </p>
              <a id="amb-success-explore" href={~p"/community"} class="amb-button amb-button-product">Explore RationalGrid
              <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
            </div>
            <.form
              :if={!@joined?}
              for={@form}
              id="ambassador-interest-form"
              phx-change="validate"
              phx-submit="join"
            >
              <h3>Let’s build this together.</h3>
              <p>Leave your email for hub, revenue-share, and early-access updates.</p>
              <.input
                field={@form[:email]}
                type="email"
                label="Email address"
                placeholder="you@example.com"
                autocomplete="email"
                required
                maxlength="254"
                class="amb-input"
              />
              <.input
                field={@form[:role]}
                type="select"
                label="I’m joining as…"
                prompt="Choose your role"
                options={[
                  {"An educator", "educator"},
                  {"An independent tutor", "tutor"},
                  {"A school or institution", "institution"},
                  {"A student", "student"},
                  {"Other", "other"}
                ]}
                required
                class="amb-input"
              />
              <.input
                :if={@form[:role].value in ["other", :other]}
                field={@form[:other_role]}
                label="Your role"
                placeholder="Tell us how you’re involved in learning"
                maxlength="100"
                required
                class="amb-input"
              />
              <p
                :if={@submission_error}
                id="ambassador-submit-error"
                role="alert"
                class="amb-form-error"
              >
                {@submission_error}
              </p>
              <button
                id="ambassador-submit"
                type="submit"
                class="amb-button"
                disabled={!@signup_available?}
                phx-disable-with="Saving your interest…"
              >Register my interest <.icon name="hero-arrow-up-right" class="h-4 w-4" /></button>
              <p
                :if={!@signup_available?}
                id="ambassador-registration-pending"
                role="status"
                class="amb-signup-note"
              >
                Registration opens soon. Please check back shortly.
              </p>
              <p class="amb-signup-note">
                By joining, you’re asking to receive emails about this programme. No account, payment, or commitment required.
              </p>
            </.form>
          </div>
        </section>

        <section id="ambassador-faq" class="amb-faq amb-container" aria-labelledby="amb-faq-title">
          <div>
            <p class="amb-eyebrow">A FEW THINGS YOU MIGHT BE WONDERING</p><h2 id="amb-faq-title">
              Good questions.<br />Thoughtful answers.
            </h2>
          </div>
          <div class="amb-faq-items">
            <details id="amb-faq-try-today">
              <summary>
                How can I try RationalGrid today?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                Try Simple answers without an account. Sign up free to organise grids in
                My Learning, save bookmarks and highlights, and explore with others.
                Branded hubs and revenue sharing are still in development. <a
                  id="amb-faq-try-link"
                  href={~p"/?focus=grid#start-here"}
                  class="font-semibold underline underline-offset-4"
                >Try RationalGrid today</a>.
              </p>
            </details>
            <details id="amb-faq-product">
              <summary>
                How does my hub connect to RationalGrid?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                The proposed hub would bring RationalGrid’s shared grids and organised workspace
                into a space with your branding and guidance. You can use RationalGrid today
                while we develop hubs with early educators.
              </p>
            </details>
            <details id="amb-faq-return">
              <summary>
                Why would students keep coming back?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                Give them a question to build on. Before the next lesson, ask them to recall an
                explanation, reopen it to check their understanding, and bring back a new question.
                My Learning keeps their grids and saved passages ready for revision.
              </p>
            </details>
            <details id="amb-faq-eligibility">
              <summary>
                Who can become an ambassador?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                We’d love to hear from teachers, lecturers, independent tutors, schools, and institutions interested in guiding thoughtful AI use. Students can also register interest in the proposed peer referral programme.
              </p>
            </details>
            <details id="amb-faq-cost">
              <summary>
                Does it cost anything to join?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                Registering your interest is free and involves no commitment. We’ll share pricing and full programme terms before you decide whether to take part.
              </p>
            </details>
            <details id="amb-faq-earnings">
              <summary>
                How will revenue sharing work?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                The proposed model gives educators a share of eligible subscriptions from students they bring to their hub, with a separate referral opportunity for students. Rates, eligibility, and payment terms are still being developed and will be confirmed before launch.
              </p>
            </details>
            <details id="amb-faq-launch">
              <summary>When can I launch my hub?<.icon name="hero-plus" class="h-4 w-4" /></summary><p>
                We’re collecting interest to shape the first version of the programme. A launch date hasn’t been set yet. Join the list for updates and opportunities to help shape early access.
              </p>
            </details>
            <details id="amb-faq-student-learning">
              <summary>
                How can I see what students are using AI for?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                Ask students to sign in and share their grids with you. Review their questions,
                AI responses, and follow-ups, then ask them to explain their choices and check
                sources. Group shared grids into your own Collections by class or project to
                guide feedback and plan the next lesson.
              </p>
            </details>
            <details id="amb-faq-contributors">
              <summary>
                Can I see who asked each question?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                In grids shared with you, signed-in students’ contributions show their profile
                username when available; AI responses are labelled separately. Ask students to
                set a username you recognise. Anonymous contributions appear as guests.
              </p>
            </details>
          </div>
        </section>

        <footer class="amb-footer amb-container">
          <a href={~p"/"} class="amb-brand">
            <span class="amb-brand-icon">
              <img
                id="amb-footer-logo"
                src={~p"/images/brandmark.svg"}
                alt=""
                width="20"
                height="20"
                class="h-5 w-5"
              />
            </span>
            RationalGrid<span class="amb-brand-dot">.</span>
          </a><p>
            Independent thinking. Shared possibility.
          </p><a id="amb-footer-about" href={~p"/about"}>Get to know RationalGrid
          <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
        </footer>
      </div>
    </Layouts.app>
    """
  end
end
